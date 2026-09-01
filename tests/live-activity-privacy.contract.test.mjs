import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const widgetPath = new URL("../ios/Nido/NidoLiveActivity/NidoLiveActivityWidget.swift", import.meta.url);

function closureAfter(source, marker) {
  const markerIndex = source.indexOf(marker);
  assert.notEqual(markerIndex, -1, `missing Live Activity surface: ${marker}`);
  const openingBrace = source.indexOf("{", markerIndex + marker.length);
  assert.notEqual(openingBrace, -1, `missing closure for Live Activity surface: ${marker}`);

  let depth = 0;
  for (let index = openingBrace; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}") depth -= 1;
    if (depth === 0) return source.slice(openingBrace + 1, index);
  }
  assert.fail(`unterminated closure for Live Activity surface: ${marker}`);
}

test("every Live Activity disclosure surface is privacy sensitive", async () => {
  const source = await readFile(widgetPath, "utf8");
  const surfaces = new Map([
    ["lock screen", "ActivityConfiguration(for: NidoActivityAttributes.self)"],
    ["expanded leading", "DynamicIslandExpandedRegion(.leading)"],
    ["expanded center", "DynamicIslandExpandedRegion(.center)"],
    ["expanded trailing", "DynamicIslandExpandedRegion(.trailing)"],
    ["expanded bottom", "DynamicIslandExpandedRegion(.bottom)"],
    ["compact leading", "compactLeading:"],
    ["compact trailing", "compactTrailing:"],
    ["minimal", "minimal:"],
  ]);

  for (const [name, marker] of surfaces) {
    assert.match(
      closureAfter(source, marker),
      /\.privacySensitive\(\)/,
      `${name} can disclose baby or activity data without privacy redaction`,
    );
  }
});
