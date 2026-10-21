function assert(condition, message) {
  if (!condition) throw new Error(message);
}

export function validateResultSummary(output, expectedCount, phaseName) {
  assert(Number.isSafeInteger(expectedCount) && expectedCount > 0, `${phaseName}: expected test count must be a positive integer.`);

  let summary;
  try {
    summary = JSON.parse(output);
  } catch {
    throw new Error(`${phaseName}: xcresulttool returned invalid JSON.`);
  }

  assert(summary && typeof summary === 'object' && !Array.isArray(summary), `${phaseName}: xcresult summary must be an object.`);
  assert(summary.result === 'Passed', `${phaseName}: xcresult result must be Passed; observed ${String(summary.result)}.`);
  for (const field of ['totalTestCount', 'passedTests', 'failedTests', 'skippedTests']) {
    assert(Number.isSafeInteger(summary[field]) && summary[field] >= 0, `${phaseName}: xcresult summary is missing a valid ${field}.`);
  }
  assert(summary.totalTestCount === expectedCount,
    `${phaseName}: expected ${expectedCount} test results, observed ${summary.totalTestCount}.`);
  assert(summary.passedTests === expectedCount,
    `${phaseName}: expected ${expectedCount} passed tests, observed ${summary.passedTests}.`);
  assert(summary.failedTests === 0, `${phaseName}: expected zero failed tests, observed ${summary.failedTests}.`);
  assert(summary.skippedTests === 0, `${phaseName}: expected zero skipped tests, observed ${summary.skippedTests}.`);

  return {
    total: summary.totalTestCount,
    passed: summary.passedTests,
    failed: summary.failedTests,
    skipped: summary.skippedTests,
  };
}

export function validateDiagnosticResultSummary(output, expectedCount, phaseName) {
  assert(Number.isSafeInteger(expectedCount) && expectedCount > 0, `${phaseName}: expected test count must be a positive integer.`);
  let summary;
  try { summary = JSON.parse(output); } catch { throw new Error(`${phaseName}: xcresulttool returned invalid JSON.`); }
  assert(summary && typeof summary === 'object' && !Array.isArray(summary), `${phaseName}: xcresult summary must be an object.`);
  for (const field of ['totalTestCount', 'passedTests', 'failedTests', 'skippedTests']) {
    assert(Number.isSafeInteger(summary[field]) && summary[field] >= 0, `${phaseName}: xcresult summary is missing a valid ${field}.`);
  }
  assert(summary.totalTestCount === expectedCount, `${phaseName}: expected ${expectedCount} test results, observed ${summary.totalTestCount}.`);
  assert(summary.skippedTests === 0, `${phaseName}: expected zero skipped tests, observed ${summary.skippedTests}.`);
  assert(summary.passedTests + summary.failedTests === expectedCount, `${phaseName}: test result counts do not match the planned execution count.`);
  if (summary.failedTests === 0) assert(summary.result === 'Passed', `${phaseName}: xcresult result must be Passed; observed ${String(summary.result)}.`);
  else assert(summary.result === 'Failed', `${phaseName}: failed diagnostic cases must report Failed; observed ${String(summary.result)}.`);
  return { total: summary.totalTestCount, passed: summary.passedTests, failed: summary.failedTests,
    skipped: summary.skippedTests, findings: summary.failedTests > 0 };
}

export function validateDiagnosticTestTree(output, expectedSelector, expectedResult, phaseName) {
  let tree;
  try { tree = JSON.parse(output); } catch { throw new Error(`${phaseName}: xcresult test tree returned invalid JSON.`); }
  assert(tree && typeof tree === 'object' && Array.isArray(tree.testNodes), `${phaseName}: xcresult test tree is missing testNodes.`);
  const parts = expectedSelector.split('/');
  assert(parts.length === 3 && parts.every(Boolean), `${phaseName}: expected raw diagnostic selector must include target, class, and test.`);
  const [target, testClass, method] = parts;
  const expectedIdentifier = `${testClass}/${method}()`;
  const expectedURL = `test://com.apple.xcode/Nido/${target}/${testClass}/${method}`;
  const cases = [];
  const visit = (nodes) => {
    for (const node of nodes) {
      if (!node || typeof node !== 'object') continue;
      if (node.nodeType === 'Test Case') cases.push(node);
      if (Array.isArray(node.children)) visit(node.children);
    }
  };
  visit(tree.testNodes);
  assert(cases.length === 1 && cases[0].nodeIdentifier === expectedIdentifier && cases[0].nodeIdentifierURL === expectedURL,
    `${phaseName}: xcresult must contain exactly the expected raw diagnostic test ${expectedSelector}.`);
  assert(cases[0].result === expectedResult,
    `${phaseName}: expected raw diagnostic test result ${expectedResult}, observed ${String(cases[0].result)}.`);
  return cases[0].result;
}

export function summarizeAppearanceResults(results, expectedExecutions) {
  const completedExecutions = results.reduce((sum, phase) => sum + phase.count, 0);
  assert(completedExecutions === expectedExecutions,
    `Expected ${expectedExecutions} executions, got ${completedExecutions}.`);
  const ordinaryPassed = results.filter((phase) => !phase.status)
    .reduce((sum, phase) => sum + phase.counts.passed, 0);
  const diagnostics = results.filter((phase) => phase.status);
  const diagnosticPassed = diagnostics.reduce((sum, phase) => sum + phase.counts.passed, 0);
  const diagnosticFailed = diagnostics.reduce((sum, phase) => sum + phase.counts.failed, 0);
  const findings = diagnosticFailed > 0;
  return {
    summary: { completedExecutions, ordinaryPassed, diagnosticPassed, diagnosticFailed,
      status: findings ? 'completed_with_diagnostic_findings' : 'passed' },
    exitCode: findings ? 2 : 0,
  };
}
