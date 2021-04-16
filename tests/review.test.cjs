"use strict";
const assert = require("node:assert/strict");
const {
  frameAt,
  sourceIntervals,
} = require("../src/murmur/assets/review-core.js");
assert.equal(frameAt(2.55, 24000, 184800), 61200);
assert.equal(frameAt(7.7, 24000, 184800), 184799);
assert.equal(frameAt(-1, 24000, 184800), 0);
assert.throws(() => frameAt(NaN, 24000, 1), RangeError);
const plan = {
  rate: 48000,
  frames: 96000,
  sources: [{ id: "field", rate: 22050 }],
  clips: [
    {
      source: "field",
      sourceStart: 2205,
      sourceEnd: 46305,
      at: 0,
      frames: 96000,
    },
    {
      source: "field",
      sourceStart: 2205,
      sourceEnd: 24255,
      at: 48000,
      frames: 48000,
    },
  ],
};
assert.deepEqual(sourceIntervals(plan, 1, 1.5), [
  { source: "field", rate: 22050, start: 2205, end: 13230 },
  { source: "field", rate: 22050, start: 24255, end: 35280 },
]);
assert.deepEqual(sourceIntervals(plan, 0, 2), [
  { source: "field", rate: 22050, start: 2205, end: 46305 },
]);
assert.deepEqual(sourceIntervals(plan, 3, 4), []);
assert.throws(() => sourceIntervals(plan, 1, 1), RangeError);
console.log("review arithmetic: 8 checks passed");
