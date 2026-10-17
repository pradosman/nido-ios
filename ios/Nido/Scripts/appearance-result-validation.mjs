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
