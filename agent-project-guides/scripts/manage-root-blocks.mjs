#!/usr/bin/env node

import fs from 'node:fs';

function fail(message) {
  console.error(`error: ${message}`);
  process.exit(1);
}

function markerRange(buffer, startText, endText, required) {
  const start = Buffer.from(startText);
  const end = Buffer.from(endText);
  const startAt = buffer.indexOf(start);
  if (startAt === -1) {
    if (required) fail(`missing start marker: ${startText}`);
    return undefined;
  }
  if (buffer.indexOf(start, startAt + start.length) !== -1) fail(`duplicate start marker: ${startText}`);

  const endAt = buffer.indexOf(end, startAt + start.length);
  if (endAt === -1) fail(`missing end marker: ${endText}`);
  if (buffer.indexOf(end, endAt + end.length) !== -1) fail(`duplicate end marker: ${endText}`);

  let after = endAt + end.length;
  if (buffer[after] === 0x0d && buffer[after + 1] === 0x0a) after += 2;
  else if (buffer[after] === 0x0a) after += 1;
  return { startAt, after };
}

function strip(buffer, markerPairs) {
  let result = buffer;
  for (const [start, end] of markerPairs) {
    const range = markerRange(result, start, end, false);
    if (range) result = Buffer.concat([result.subarray(0, range.startAt), result.subarray(range.after)]);
  }
  return result;
}

const [command, inputPath, outputPath, ...args] = process.argv.slice(2);
if (!command || !inputPath || !outputPath) {
  fail('usage: manage-root-blocks.mjs <strip|replace> INPUT OUTPUT ...');
}

const input = fs.readFileSync(inputPath);

if (command === 'strip') {
  if (args.length === 0 || args.length % 2 !== 0) fail('strip requires one or more START END marker pairs');
  const pairs = [];
  for (let index = 0; index < args.length; index += 2) pairs.push([args[index], args[index + 1]]);
  fs.writeFileSync(outputPath, strip(input, pairs));
} else if (command === 'replace') {
  if (args.length !== 3) fail('replace requires START END REPLACEMENT_FILE');
  const [start, end, replacementPath] = args;
  const range = markerRange(input, start, end, true);
  const replacement = fs.readFileSync(replacementPath);
  fs.writeFileSync(outputPath, Buffer.concat([
    input.subarray(0, range.startAt),
    replacement,
    input.subarray(range.after),
  ]));
} else {
  fail(`unknown command: ${command}`);
}
