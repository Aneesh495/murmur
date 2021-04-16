"use strict";
// Pure timeline arithmetic shared by the browser and Node's independent tests.
// Media currentTime is a floating clock, so displayed frames round to nearest.
const MurmurCore = (() => {
  function frameAt(seconds, rate, frames) {
    if (
      !Number.isFinite(seconds) ||
      !Number.isSafeInteger(rate) ||
      rate <= 0 ||
      !Number.isSafeInteger(frames) ||
      frames < 1
    ) {
      throw new RangeError("Invalid media clock");
    }
    return Math.max(0, Math.min(frames - 1, Math.round(seconds * rate)));
  }
  function sourceIntervals(plan, startSeconds, endSeconds) {
    if (
      !Number.isFinite(startSeconds) ||
      !Number.isFinite(endSeconds) ||
      startSeconds < 0 ||
      endSeconds <= startSeconds
    ) {
      throw new RangeError("Invalid selection");
    }
    const lo = Math.max(0, Math.floor(startSeconds * plan.rate));
    const hi = Math.min(plan.frames, Math.ceil(endSeconds * plan.rate));
    const intervals = [];
    for (const clip of plan.clips) {
      const start = Math.max(lo, clip.at),
        end = Math.min(hi, clip.at + clip.frames);
      if (start >= end) continue;
      const source = plan.sources.find((s) => s.id === clip.source);
      if (!source) throw new Error("Missing clip source");
      const from = Math.max(
        clip.sourceStart,
        Math.floor(
          clip.sourceStart + ((start - clip.at) * source.rate) / plan.rate,
        ),
      );
      const to = Math.min(
        clip.sourceEnd,
        Math.ceil(
          clip.sourceStart + ((end - clip.at) * source.rate) / plan.rate,
        ),
      );
      if (from < to)
        intervals.push({
          source: source.id,
          rate: source.rate,
          start: from,
          end: to,
        });
    }
    intervals.sort(
      (a, b) => a.source.localeCompare(b.source) || a.start - b.start,
    );
    const merged = [];
    for (const item of intervals) {
      const previous = merged[merged.length - 1];
      if (
        previous &&
        previous.source === item.source &&
        item.start <= previous.end
      )
        previous.end = Math.max(previous.end, item.end);
      else merged.push({ ...item });
    }
    return merged;
  }
  return { frameAt, sourceIntervals };
})();
if (typeof module !== "undefined") module.exports = MurmurCore;
