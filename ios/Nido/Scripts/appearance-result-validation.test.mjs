import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { validateResultSummary } from './appearance-result-validation.mjs';
import { runXcodePhase, runAPIPhase } from './run-appearance-phased-ui-tests.mjs';

function summary(total, overrides = {}) {
  return JSON.stringify({
    result: 'Passed',
    totalTestCount: total,
    passedTests: total,
    failedTests: 0,
    skippedTests: 0,
    ...overrides,
  });
}

test('accepts only a successful summary with the exact planned test count', () => {
  for (const expected of [111, 3, 43, 10]) {
    assert.deepEqual(validateResultSummary(summary(expected), expected, 'phase'), {
      total: expected,
      passed: expected,
      failed: 0,
      skipped: 0,
    });
  }
});

test('accepts the Passed result value emitted by xcresulttool', () => {
  const fixture = JSON.parse(readFileSync(new URL('./fixtures/xcresult-summary-passed.json', import.meta.url), 'utf8'));
  assert.deepEqual(validateResultSummary(JSON.stringify(fixture.summary), 1, 'dark-ui'), {
    total: 1,
    passed: 1,
    failed: 0,
    skipped: 0,
  });
});

test('rejects missing, malformed, skipped, failed, or incomplete result summaries', () => {
  for (const invalid of [
    'not json',
    JSON.stringify({ result: 'SUCCESS' }),
    summary(111, { result: 'Failed' }),
    summary(111, { result: 'SUCCESS' }),
    summary(111, { totalTestCount: 0, passedTests: 0 }),
    summary(111, { totalTestCount: 110, passedTests: 110 }),
    summary(111, { passedTests: 110, failedTests: 1 }),
    summary(111, { passedTests: 110, skippedTests: 1 }),
    summary(111, { skippedTests: undefined }),
  ]) {
    assert.throws(() => validateResultSummary(invalid, 111, 'light-ui'));
  }
});

test('validates the xcresult summary after a successful xcodebuild phase', async () => {
  const resultsDir = await mkdtemp(join(tmpdir(), 'nido-result-phase-'));
  const events = [];
  try {
    const result = runXcodePhase({ name: 'light-ui', identifiers: ['A/testOne', 'A/testTwo'] }, {
      xctestrun: '/safe path/tests.xctestrun',
      'cloned-source-packages-dir': '/safe path/packages',
      'derived-data-path': '/safe path/DerivedData',
      'device-id': 'SIM-1',
      'results-dir': resultsDir,
    }, {}, {
      spawnProcess: (command, args) => {
        events.push(['xcodebuild', command, args]);
        return { status: 0 };
      },
      runCommand: (command, args) => {
        events.push(['summary', command, args]);
        return summary(2);
      },
    });
    assert.equal(result.count, 2);
    assert.deepEqual(events.map(([kind]) => kind), ['xcodebuild', 'summary']);
    assert.deepEqual(events[1].slice(1), ['xcrun', [
      'xcresulttool', 'get', 'test-results', 'summary', '--path', result.resultPath, '--compact',
    ]]);
  } finally {
    await rm(resultsDir, { recursive: true, force: true });
  }
});

test('validates the API helper result and propagates xcresult tool errors', async () => {
  const resultsDir = await mkdtemp(join(tmpdir(), 'nido-api-result-'));
  const events = [];
  try {
    await assert.rejects(async () => runAPIPhase({ name: 'local-api-ui', identifiers: ['A/api'] }, {
      'results-dir': resultsDir,
      'api-root': '/api root',
      'derived-data-path': '/derived data',
      xctestrun: '/tests.xctestrun',
      'device-id': 'SIM-1',
      'cloned-source-packages-dir': '/packages',
    }, {
      runCommand: (command, args) => {
        events.push([command, args]);
        if (args[0] === '--run-ui-tests') return '';
        throw new Error('xcresulttool unavailable');
      },
    }), /xcresulttool unavailable/);
    assert.equal(events.length, 2);
    assert.ok(events[0][1].includes('--result-bundle'));
    assert.equal(events[1][0], 'xcrun');
  } finally {
    await rm(resultsDir, { recursive: true, force: true });
  }
});

test('the API helper receives its own result bundle and must report all three planned cases', async () => {
  const resultsDir = await mkdtemp(join(tmpdir(), 'nido-api-pass-result-'));
  const events = [];
  try {
    const phase = { name: 'local-api-ui', identifiers: ['A/one', 'A/two', 'A/three'] };
    const result = runAPIPhase(phase, {
      'results-dir': resultsDir,
      'api-root': '/api root',
      'derived-data-path': '/derived data',
      xctestrun: '/tests.xctestrun',
      'device-id': 'SIM-1',
      'cloned-source-packages-dir': '/packages',
    }, {
      runCommand: (command, args) => {
        events.push([command, args]);
        return args[0] === '--run-ui-tests' ? '' : summary(3);
      },
    });
    assert.equal(result.count, 3);
    assert.equal(result.counts.passed, 3);
    assert.equal(events[0][1][events[0][1].indexOf('--result-bundle') + 1], result.resultPath);
    assert.deepEqual(events[1], ['xcrun', [
      'xcresulttool', 'get', 'test-results', 'summary', '--path', result.resultPath, '--compact',
    ]]);
  } finally {
    await rm(resultsDir, { recursive: true, force: true });
  }
});
