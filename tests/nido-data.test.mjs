import assert from "node:assert/strict";
import test from "node:test";
import {
  ageInMonths, calculateDayMetrics, calculateWeekSleep, formatMinutes,
  wakeWindowMinutes,
} from "../app/nido-data.ts";

const noon = new Date(2026, 7, 27, 12, 0, 0).getTime();
const previousDay = noon - 86_400_000;

test("daily metrics use only entries from the requested day", () => {
  const entries = [
    { id: "1", kind: "sleep", title: "Sueño", detail: "", occurredAt: noon, durationMinutes: 90, amountMl: null },
    { id: "2", kind: "feed", title: "Biberón", detail: "", occurredAt: noon, durationMinutes: null, amountMl: 120 },
    { id: "3", kind: "diaper", title: "Pañal", detail: "", occurredAt: noon, durationMinutes: null, amountMl: null },
    { id: "4", kind: "sleep", title: "Sueño", detail: "", occurredAt: previousDay, durationMinutes: 300, amountMl: null },
  ];
  assert.deepEqual(calculateDayMetrics(entries, noon), { sleepMinutes: 90, feeds: 1, feedMl: 120, diapers: 1 });
});

test("weekly sleep starts empty and aggregates real durations", () => {
  const empty = calculateWeekSleep([], noon);
  assert.deepEqual(empty, [0, 0, 0, 0, 0, 0, 0]);
  const entries = [{ id: "1", kind: "sleep", title: "Sueño", detail: "", occurredAt: noon, durationMinutes: 75, amountMl: null }];
  assert.equal(calculateWeekSleep(entries, noon).at(-1), 75);
});

test("age-aware helpers remain deterministic", () => {
  assert.equal(ageInMonths("2026-04-14", new Date("2026-08-27T12:00:00")), 4);
  assert.equal(wakeWindowMinutes(4), 105);
  assert.equal(formatMinutes(78), "1 h 18 min");
});
