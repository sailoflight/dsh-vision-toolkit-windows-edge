"""One-shot Microsoft Edge renderer. stdin is JSON; stdout is framed header + PNG."""
from __future__ import annotations

import base64
import hashlib
import json
import ntpath
import struct
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent
CONFIG_PATH = ROOT / "config.json"
MAX_HEADER_BYTES = 16 * 1024
MAX_PNG_BYTES = 64 * 1024 * 1024
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def fail(code: str, message: str) -> None:
    header = json.dumps({"v": 1, "ok": False, "error": {"code": code, "message": message[:1000]}}, separators=(",", ":")).encode()
    sys.stdout.buffer.write(struct.pack(">I", len(header)) + header)
    sys.stdout.buffer.flush()


def integer(value: object, minimum: int, maximum: int, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        raise ValueError(f"{name} must be an integer from {minimum} through {maximum}")
    return value


def load_roots() -> list[str]:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    roots = config.get("allowedRoots")
    if not isinstance(roots, list) or not roots:
        raise ValueError("allowedRoots is not configured")
    result = []
    for root in roots:
        if not isinstance(root, str) or not root.startswith("\\\\wsl.localhost\\"):
            raise ValueError("allowedRoots must contain canonical \\wsl.localhost UNC paths")
        result.append(ntpath.normcase(ntpath.normpath(root)))
    return result


ALLOWED_ROOTS = load_roots()


def is_allowed(path: str) -> bool:
    if path.startswith(("\\\\?\\", "\\\\.\\")) or not path.startswith("\\\\wsl.localhost\\"):
        return False
    normalized = ntpath.normcase(ntpath.normpath(path))
    if ":" in normalized[len("\\\\wsl.localhost\\"):]:
        return False
    for root in ALLOWED_ROOTS:
        try:
            if ntpath.commonpath([root, normalized]) == root:
                return True
        except ValueError:
            continue
    return False


def file_url_path(url: str) -> str | None:
    parsed = urlsplit(url)
    if parsed.scheme.lower() != "file" or not parsed.netloc:
        return None
    return "\\\\" + parsed.netloc + unquote(parsed.path).replace("/", "\\")


def png_dimensions(png: bytes) -> tuple[int, int]:
    if len(png) < 24 or png[:8] != PNG_SIGNATURE:
        raise ValueError("Edge returned invalid PNG bytes")
    return struct.unpack(">II", png[16:24])


def main() -> None:
    raw = sys.stdin.buffer.read(MAX_HEADER_BYTES + 1)
    if len(raw) > MAX_HEADER_BYTES:
        raise ValueError("worker request exceeds maximum header size")
    request = json.loads(raw.decode("utf-8"))
    if not isinstance(request, dict) or request.get("v") != 1 or request.get("op") != "screenshot":
        raise ValueError("unsupported worker request")
    source_value = request.get("source")
    if not isinstance(source_value, str) or not is_allowed(source_value):
        raise ValueError("source is outside configured WSL roots")
    source = Path(source_value)
    if source.suffix.lower() not in {".html", ".htm"} or not source.is_file():
        raise ValueError("source must be an existing local HTML file")
    max_source_bytes = integer(request.get("maxSourceBytes"), 1, 268435456, "maxSourceBytes")
    if source.stat().st_size > max_source_bytes:
        raise ValueError("HTML source exceeds maxSourceBytes")

    viewport = request.get("viewport")
    if not isinstance(viewport, dict):
        raise ValueError("viewport is required")
    width = integer(viewport.get("width"), 1, 8192, "viewport.width")
    height = integer(viewport.get("height"), 1, 8192, "viewport.height")
    scale = integer(viewport.get("scale"), 1, 4, "viewport.scale")
    wait_ms = integer(request.get("waitMs"), 0, 120000, "waitMs")
    timeout_ms = integer(request.get("timeoutMs"), 1000, 600000, "timeoutMs")
    max_pixels = integer(request.get("maxPixels"), 1, 268435456, "maxPixels")
    full_page = request.get("fullPage") is True
    if width * height * scale * scale > max_pixels:
        raise ValueError("requested viewport exceeds maxPixels")

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            channel="msedge",
            headless=True,
            args=[
                "--disable-background-networking",
                "--disable-gpu",
                "--hide-scrollbars",
                "--no-first-run",
                "--no-default-browser-check",
                "--use-mock-keychain",
            ],
        )
        try:
            context = browser.new_context(
                viewport={"width": width, "height": height},
                device_scale_factor=scale,
                offline=True,
                service_workers="block",
                accept_downloads=False,
            )
            try:
                page = context.new_page()
                page.set_default_timeout(timeout_ms)
                page.set_default_navigation_timeout(timeout_ms)

                def guard(route) -> None:
                    url = route.request.url
                    scheme = urlsplit(url).scheme.lower()
                    if scheme == "file":
                        local = file_url_path(url)
                        if local is not None and is_allowed(local):
                            route.continue_()
                        else:
                            route.abort("blockedbyclient")
                    elif scheme in {"data", "blob", "about"}:
                        route.continue_()
                    else:
                        route.abort("blockedbyclient")

                page.route("**/*", guard)
                page.goto(source.as_uri(), wait_until="load", timeout=timeout_ms)
                page.evaluate("() => document.fonts ? document.fonts.ready : Promise.resolve()")
                if wait_ms:
                    page.wait_for_timeout(wait_ms)

                page_height: int | None = None
                if full_page:
                    page.evaluate("""
                        () => {
                          document.documentElement.style.scrollBehavior = 'auto';
                          if (document.body) document.body.style.scrollBehavior = 'auto';
                          window.scrollTo(0, 0);
                        }
                    """)
                    page_height = int(page.evaluate("""
                        () => Math.max(document.documentElement.scrollHeight,
                                       document.body ? document.body.scrollHeight : 0)
                    """) or 0)
                    for _ in range(2):
                        measured = page_height
                        for position in range(0, page_height, max(1, height)):
                            page.evaluate("position => window.scrollTo(0, position)", position)
                            page.wait_for_timeout(120)
                        page.evaluate("position => window.scrollTo(0, position)", page_height)
                        page.wait_for_timeout(120)
                        page_height = int(page.evaluate("""
                            () => Math.max(document.documentElement.scrollHeight,
                                           document.body ? document.body.scrollHeight : 0)
                        """) or 0)
                        if page_height <= measured:
                            break
                    page.evaluate("() => window.scrollTo(0, 0)")
                    if page_height <= 0:
                        raise ValueError("page reported an invalid full-page height")
                    if width * page_height * scale * scale > max_pixels:
                        raise ValueError("full-page screenshot exceeds maxPixels")

                page.evaluate("""
                    () => Promise.race([
                      Promise.all(Array.from(document.images)
                        .filter(image => !image.complete)
                        .map(image => new Promise(resolve => {
                          image.addEventListener('load', resolve, { once: true });
                          image.addEventListener('error', resolve, { once: true });
                        }))),
                      new Promise(resolve => setTimeout(resolve, 3000))
                    ])
                """)
                if full_page:
                    session = context.new_cdp_session(page)
                    captured = session.send("Page.captureScreenshot", {
                        "format": "png",
                        "fromSurface": True,
                        "captureBeyondViewport": True,
                        "clip": {"x": 0, "y": 0, "width": width, "height": page_height, "scale": 1},
                    })
                    png = base64.b64decode(captured["data"])
                else:
                    png = page.screenshot(full_page=False, animations="disabled", caret="hide", type="png", scale="device")
            finally:
                context.close()
            browser_version = browser.version
        finally:
            browser.close()

    if len(png) > MAX_PNG_BYTES:
        raise ValueError("rendered PNG exceeds 64 MiB")
    pixel_width, pixel_height = png_dimensions(png)
    expected_width = width * scale
    expected_height = (page_height if page_height is not None else height) * scale
    if pixel_width != expected_width or pixel_height != expected_height:
        raise ValueError(f"PNG dimensions {pixel_width}x{pixel_height} do not match expected {expected_width}x{expected_height}")
    header = {
        "v": 1,
        "ok": True,
        "mime": "image/png",
        "bytes": len(png),
        "sha256": hashlib.sha256(png).hexdigest(),
        "width": pixel_width,
        "height": pixel_height,
        **({"pageHeight": page_height} if page_height is not None else {}),
        "browser": "msedge",
        "browserVersion": browser_version,
    }
    encoded = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    sys.stdout.buffer.write(struct.pack(">I", len(encoded)) + encoded + png)
    sys.stdout.buffer.flush()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        fail("RENDER", str(error).replace("\r", " ").replace("\n", " "))
