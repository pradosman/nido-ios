import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { validateResultSummary, validateDiagnosticResultSummary, summarizeAppearanceResults } from './appearance-result-validation.mjs';
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

function diagnosticTree(identifier, result, child = undefined) {
  const [target, testClass, method] = identifier.split('/');
  return JSON.stringify({ testNodes: [{ nodeType: 'Test Plan', children: [{ nodeType: 'UI test bundle', children: [{
    nodeType: 'Test Suite', children: [{ nodeType: 'Test Case', result,
      name: `${method}()`, nodeIdentifier: `${testClass}/${method}()`,
      nodeIdentifierURL: `test://com.apple.xcode/Nido/${target}/${testClass}/${method}`,
      ...(child ? { children: [{ nodeType: 'Failure Message', name: child }] } : {}),
    }],
  }] }] }] });
}

const RAW_LIGHT_DIAGNOSTIC = 'NidoUITests/NidoUITests/testTodayUnfilteredAccessibilityAuditDiagnosticInLightAppearance';

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

test('diagnostic summary retains XCTest failures but rejects skips and missing executions', () => {
  assert.deepEqual(validateDiagnosticResultSummary(summary(1, {
    result: 'Failed', passedTests: 0, failedTests: 1,
  }), 1, 'diagnostic'), { total: 1, passed: 0, failed: 1, skipped: 0, findings: true });
  assert.throws(() => validateDiagnosticResultSummary(summary(1, {
    result: 'Failed', passedTests: 0, failedTests: 0, skippedTests: 1,
  }), 1, 'diagnostic'), /skipped/);
  assert.throws(() => validateDiagnosticResultSummary(summary(0), 1, 'diagnostic'), /expected 1 test results/);
});

test('diagnostic findings retain a complete summary and produce a distinct nonzero exit code', () => {
  const outcome = summarizeAppearanceResults([
    { count: 198, counts: { passed: 198 } },
    { count: 1, status: 'passed', counts: { passed: 1, failed: 0 } },
    { count: 1, status: 'completed_with_diagnostic_findings', counts: { passed: 0, failed: 1 } },
  ], 200);
  assert.deepEqual(outcome, {
    summary: { completedExecutions: 200, ordinaryPassed: 198, diagnosticPassed: 1,
      diagnosticFailed: 1, status: 'completed_with_diagnostic_findings' },
    exitCode: 2,
  });
  assert.throws(() => summarizeAppearanceResults([{ count: 199, counts: { passed: 199 } }], 200), /Expected 200 executions/);
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

test('retains an exact failed raw diagnostic result after xcodebuild reports assertion failure', async () => {
  const resultsDir = await mkdtemp(join(tmpdir(), 'nido-diagnostic-result-'));
  try {
    const result = runXcodePhase({ name: 'raw-diagnostic', kind: 'diagnostic', identifiers: [RAW_LIGHT_DIAGNOSTIC] }, {
      xctestrun: '/tests.xctestrun', 'cloned-source-packages-dir': '/packages',
      'derived-data-path': '/derived', 'device-id': 'SIM-1', 'results-dir': resultsDir,
    }, {}, {
      spawnProcess: () => ({ status: 65 }),
      runCommand: (_command, args) => args.includes('tests')
        ? diagnosticTree(RAW_LIGHT_DIAGNOSTIC, 'Failed', 'setUpWithError failed')
        : summary(1, { result: 'Failed', passedTests: 0, failedTests: 1 }),
    });
    assert.equal(result.counts.failed, 1);
    assert.equal(result.status, 'completed_with_diagnostic_findings');
  } finally {
    await rm(resultsDir, { recursive: true, force: true });
  }
});

test('accepts a passing diagnostic only when its xcresult tree names the planned raw test', async () => {
  const resultsDir = await mkdtemp(join(tmpdir(), 'nido-diagnostic-passed-'));
  try {
    const result = runXcodePhase({ name: 'raw-diagnostic', kind: 'diagnostic', identifiers: [RAW_LIGHT_DIAGNOSTIC] }, {
      xctestrun: '/tests.xctestrun', 'cloned-source-packages-dir': '/packages',
      'derived-data-path': '/derived', 'device-id': 'SIM-1', 'results-dir': resultsDir,
    }, {}, {
      spawnProcess: () => ({ status: 0, signal: null }),
      runCommand: (_command, args) => args.includes('tests')
        ? diagnosticTree(RAW_LIGHT_DIAGNOSTIC, 'Passed')
        : summary(1),
    });
    assert.equal(result.counts.passed, 1);
    assert.equal(result.status, 'passed');
  } finally {
    await rm(resultsDir, { recursive: true, force: true });
  }
});

test('rejects diagnostic signal, infrastructure, and inconsistent exit kinds before reading xcresult', async () => {
  const resultsDir = await mkdtemp(join(tmpdir(), 'nido-diagnostic-exit-kind-'));
  try {
    for (const child of [
      { status: null, signal: 'SIGTERM' },
      { status: 69, signal: null },
      { status: 70, signal: null },
      { status: 1, signal: null },
    ]) {
      let summaryRead = false;
      const resultSummary = summary(1, { result: 'Failed', passedTests: 0, failedTests: 1 });
      assert.throws(() => runXcodePhase({ name: 'raw-diagnostic', kind: 'diagnostic', identifiers: ['A/diagnostic'] }, {
        xctestrun: '/tests.xctestrun', 'cloned-source-packages-dir': '/packages',
        'derived-data-path': '/derived', 'device-id': 'SIM-1', 'results-dir': resultsDir,
      }, {}, {
        spawnProcess: () => child,
        runCommand: () => { summaryRead = true; return resultSummary; },
      }), /Phase raw-diagnostic failed/);
      assert.equal(summaryRead, false, `xcresult must not override child exit ${child.status ?? child.signal}`);
      await rm(join(resultsDir, 'raw-diagnostic.log'), { force: true });
    }
    let summaryRead = false;
    assert.throws(() => runXcodePhase({ name: 'raw-diagnostic', kind: 'diagnostic', identifiers: ['A/diagnostic'] }, {
      xctestrun: '/tests.xctestrun', 'cloned-source-packages-dir': '/packages',
      'derived-data-path': '/derived', 'device-id': 'SIM-1', 'results-dir': resultsDir,
    }, {}, {
      spawnProcess: () => ({ status: 0, signal: null }),
      runCommand: () => { summaryRead = true; return summary(1, { result: 'Failed', passedTests: 0, failedTests: 1 }); },
    }), /result must be Passed/);
    assert.equal(summaryRead, true);
  } finally {
    await rm(resultsDir, { recursive: true, force: true });
  }
});

test('rejects unrelated SetupFailure and wrong raw selector despite an exact one-failure summary', async () => {
  const resultsDir = await mkdtemp(join(tmpdir(), 'nido-diagnostic-identity-'));
  try {
    for (const unrelated of [
      'NidoUITests/NidoUITests/SetupFailure',
      'NidoUITests/OtherUITests/testTodayUnfilteredAccessibilityAuditDiagnosticInLightAppearance',
    ]) {
      await assert.rejects(async () => runXcodePhase({ name: 'raw-diagnostic', kind: 'diagnostic', identifiers: [RAW_LIGHT_DIAGNOSTIC] }, {
        xctestrun: '/tests.xctestrun', 'cloned-source-packages-dir': '/packages',
        'derived-data-path': '/derived', 'device-id': 'SIM-1', 'results-dir': resultsDir,
      }, {}, {
        spawnProcess: () => ({ status: 65, signal: null }),
        runCommand: (_command, args) => args.includes('tests')
          ? diagnosticTree(unrelated, 'Failed')
          : summary(1, { result: 'Failed', passedTests: 0, failedTests: 1 }),
      }), /expected raw diagnostic test/);
      await rm(join(resultsDir, 'raw-diagnostic.log'), { force: true });
    }
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
