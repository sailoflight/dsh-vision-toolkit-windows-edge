"""Authenticated loopback listener that runs one short-lived Edge worker per request."""
from __future__ import annotations

import hmac
import json
import os
import socket
import struct
import subprocess
import sys
import threading
import time
from pathlib import Path

HOST = "127.0.0.1"
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8767
ROOT = Path(__file__).resolve().parent
TOKEN = (ROOT / "token").read_text(encoding="ascii").strip()
WORKER = ROOT / "render_worker.py"
LOG_PATH = ROOT / "logs" / "bridge-server.log"
MAX_HEADER_BYTES = 16 * 1024
MAX_WORKER_BYTES = 64 * 1024 * 1024 + MAX_HEADER_BYTES + 4
REQUEST_KEYS = {"v", "op", "token", "source", "viewport", "fullPage", "waitMs", "timeoutMs", "maxPixels", "maxSourceBytes"}
ACTIVE = threading.Lock()


def log(message: str) -> None:
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as stream:
            stream.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {message}\n")
    except OSError:
        pass


def recv_exact(conn: socket.socket, size: int) -> bytes:
    chunks = bytearray()
    while len(chunks) < size:
        chunk = conn.recv(size - len(chunks))
        if not chunk:
            raise ValueError("connection closed before frame completed")
        chunks.extend(chunk)
    return bytes(chunks)


def response_header(conn: socket.socket, value: dict[str, object]) -> None:
    data = json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    conn.sendall(struct.pack(">I", len(data)) + data)


def error_response(conn: socket.socket, code: str, message: str) -> None:
    response_header(conn, {"v": 1, "ok": False, "error": {"code": code, "message": message[:1000]}})


def kill_tree(process: subprocess.Popen[bytes]) -> None:
    try:
        subprocess.run(["taskkill.exe", "/PID", str(process.pid), "/T", "/F"], capture_output=True, timeout=10)
    except Exception:
        try:
            process.kill()
        except OSError:
            pass


def run_worker(request: dict[str, object]) -> bytes:
    timeout_ms = request.get("timeoutMs", 30000)
    if isinstance(timeout_ms, bool) or not isinstance(timeout_ms, int) or not 1000 <= timeout_ms <= 600000:
        raise ValueError("timeoutMs is invalid")
    child_request = dict(request)
    child_request.pop("token", None)
    payload = json.dumps(child_request, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    log_handle = LOG_PATH.open("ab")
    process = subprocess.Popen(
        [str(Path(sys.executable).with_name("python.exe")), str(WORKER)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=log_handle,
        cwd=str(ROOT),
    )
    try:
        try:
            stdout, _ = process.communicate(payload, timeout=(timeout_ms + 5000) / 1000)
        except subprocess.TimeoutExpired:
            kill_tree(process)
            process.wait(timeout=10)
            raise TimeoutError(f"render exceeded {timeout_ms} ms")
        if len(stdout) > MAX_WORKER_BYTES:
            raise ValueError("worker response exceeds maximum size")
        if process.returncode != 0 or len(stdout) < 4:
            raise RuntimeError(f"render worker exited with code {process.returncode}")
        header_size = struct.unpack(">I", stdout[:4])[0]
        if header_size <= 0 or header_size > MAX_HEADER_BYTES or len(stdout) < 4 + header_size:
            raise ValueError("worker returned an invalid response frame")
        header = json.loads(stdout[4:4 + header_size].decode("utf-8"))
        if not isinstance(header, dict):
            raise ValueError("worker response header is invalid")
        if header.get("ok") is True:
            byte_count = header.get("bytes")
            if not isinstance(byte_count, int) or byte_count < 0 or len(stdout) != 4 + header_size + byte_count:
                raise ValueError("worker PNG length does not match its header")
        elif len(stdout) != 4 + header_size:
            raise ValueError("failed worker response unexpectedly included binary data")
        return stdout
    finally:
        log_handle.close()


def handle(conn: socket.socket, address: tuple[object, ...]) -> None:
    try:
        conn.settimeout(5)
        size = struct.unpack(">I", recv_exact(conn, 4))[0]
        if size <= 0 or size > MAX_HEADER_BYTES:
            raise ValueError("request header length is invalid")
        request = json.loads(recv_exact(conn, size).decode("utf-8"))
        if not isinstance(request, dict) or request.get("v") != 1 or request.get("op") != "screenshot":
            raise ValueError("unsupported bridge request")
        unknown = set(request) - REQUEST_KEYS
        if unknown:
            raise ValueError(f"unsupported request fields: {', '.join(sorted(unknown))}")
        supplied = request.get("token")
        if not isinstance(supplied, str) or not hmac.compare_digest(supplied, TOKEN):
            error_response(conn, "AUTH", "bridge authentication failed")
            return
        if not ACTIVE.acquire(blocking=False):
            error_response(conn, "BUSY", "another screenshot is already running")
            return
        try:
            conn.settimeout(None)
            conn.sendall(run_worker(request))
        except TimeoutError as error:
            error_response(conn, "TIMEOUT", str(error))
        except Exception as error:
            log(f"worker failure: {type(error).__name__}: {error}")
            error_response(conn, "RENDER", str(error))
        finally:
            ACTIVE.release()
    except Exception as error:
        log(f"client {address} failed: {type(error).__name__}: {error}")
        try:
            error_response(conn, "INVALID_REQUEST", str(error))
        except OSError:
            pass
    finally:
        conn.close()


def main() -> None:
    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(8)
    log(f"bridge started on {HOST}:{PORT} pid={os.getpid()}")
    while True:
        conn, address = server.accept()
        threading.Thread(target=handle, args=(conn, address), daemon=True).start()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("bridge stopped by user")
    except Exception as error:
        log(f"bridge stopped: {type(error).__name__}: {error}")
        raise
