#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { mkdirSync, openSync, closeSync, existsSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildAppearancePhasePlan, readBaselineLedger, runAppearancePhases } from './appearance-phase-plan.mjs';
import { validateResultSummary, validateDiagnosticResultSummary, validateDiagnosticTestTree, summarizeAppearanceResults } from './appearance-result-validation.mjs';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const projectDir = resolve(scriptDir, '..');
const repoRoot = resolve(projectDir, '../..', '..');

function parseArgs(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (key === '--help' || key === '-h') return { help: true };
    if (!key.startsWith('--') || !argv[index + 1] || argv[index + 1].startsWith('--')) {
      throw new Error(`Expected a value after ${key}.`);
    }
    result[key.slice(2)] = argv[++index];
  }
  for (const key of ['device-id', 'xctestrun', 'derived-data-path', 'results-dir', 'cloned-source-packages-dir', 'api-root']) {
    if (!result[key]) throw new Error(`Missing required option --${key}.`);
  }
  return result;
}

function run(command, args, options = {}) {
  const child = spawnSync(command, args, { encoding: 'utf8', ...options });
  if (child.error) throw child.error;
  if (child.status !== 0) {
    throw new Error(`${command} exited with ${child.status ?? child.signal}: ${args.slice(0, 3).join(' ')}`);
  }
  return (child.stdout ?? '').trim();
}

function verifyInputPaths(options) {
  for (const [label, path] of [
    ['xctestrun', options.xctestrun],
    ['derived data', options['derived-data-path']],
    ['cloned source packages', options['cloned-source-packages-dir']],
    ['API project', options['api-root']],
  ]) {
    if (!existsSync(path)) throw new Error(`Missing ${label}: ${path}`);
  }
}

function validateResultBundle(phase, resultPath, runCommand) {
  const output = runCommand('xcrun', [
    'xcresulttool', 'get', 'test-results', 'summary', '--path', resultPath, '--compact',
  ]);
  return phase.kind === 'diagnostic'
    ? validateDiagnosticResultSummary(output, phase.identifiers.length, phase.name)
    : validateResultSummary(output, phase.identifiers.length, phase.name);
}

function runXcodePhase(phase, options, plan, { spawnProcess = spawnSync, runCommand = run } = {}) {
  const resultPath = resolve(options['results-dir'], `${phase.name}.xcresult`);
  if (existsSync(resultPath)) throw new Error(`Refusing to overwrite ${resultPath}`);
  const logPath = resolve(options['results-dir'], `${phase.name}.log`);
  const logFD = openSync(logPath, 'wx', 0o600);
  const args = [
    'test-without-building',
    '-xctestrun', options.xctestrun,
    '-clonedSourcePackagesDirPath', options['cloned-source-packages-dir'],
    '-disableAutomaticPackageResolution',
    '-skipPackageUpdates',
    '-derivedDataPath', options['derived-data-path'],
    '-destination', `platform=iOS Simulator,id=${options['device-id']}`,
    '-parallel-testing-enabled', 'NO',
    '-maximum-concurrent-test-simulator-destinations', '1',
    '-resultBundlePath', resultPath,
    ...phase.identifiers.map((identifier) => `-only-testing:${identifier}`),
  ];
  try {
    const child = spawnProcess('xcodebuild', args, { stdio: ['ignore', logFD, logFD] });
    if (child.error) throw child.error;
    if (phase.kind === 'diagnostic') {
      if (child.signal || !Number.isInteger(child.status) || ![0, 65].includes(child.status)) {
        throw new Error(`Phase ${phase.name} failed (${child.status ?? child.signal}); log: ${logPath}; result: ${resultPath}`);
      }
    } else if (child.signal || child.status !== 0) {
      throw new Error(`Phase ${phase.name} failed (${child.status ?? child.signal}); log: ${logPath}; result: ${resultPath}`);
    }
    const counts = phase.kind === 'diagnostic' && child.status === 0
      ? validateResultSummary(runCommand('xcrun', [
        'xcresulttool', 'get', 'test-results', 'summary', '--path', resultPath, '--compact',
      ]), phase.identifiers.length, phase.name)
      : validateResultBundle(phase, resultPath, runCommand);
    if (phase.kind === 'diagnostic') {
      const testTree = runCommand('xcrun', [
        'xcresulttool', 'get', 'test-results', 'tests', '--path', resultPath, '--compact',
      ]);
      validateDiagnosticTestTree(testTree, phase.identifiers[0], counts.findings ? 'Failed' : 'Passed', phase.name);
    }
    const diagnosticFindings = phase.kind === 'diagnostic' && child.status === 65 && counts.findings;
    if (phase.kind === 'diagnostic' && child.status === 65 && !diagnosticFindings) {
      throw new Error(`Phase ${phase.name} exited 65 without a complete failed XCTest diagnostic; log: ${logPath}; result: ${resultPath}`);
    }
    console.log(`${phase.name}: ${counts.passed} passed, ${counts.failed} failed${diagnosticFindings ? ' (raw diagnostic findings)' : ''}; ${resultPath}`);
    return { resultPath, logPath, count: phase.identifiers.length, counts,
      ...(phase.kind === 'diagnostic' ? { status: diagnosticFindings ? 'completed_with_diagnostic_findings' : 'passed' } : {}) };
  } finally {
    closeSync(logFD);
  }
}

function runAPIPhase(phase, options, { runCommand = run } = {}) {
  const resultPath = resolve(options['results-dir'], `${phase.name}.xcresult`);
  if (existsSync(resultPath)) throw new Error(`Refusing to overwrite ${resultPath}`);
  const evidenceDir = resolve(options['results-dir'], `${phase.name}-evidence`);
  mkdirSync(evidenceDir, { mode: 0o700 });
  const helper = resolve(projectDir, 'Scripts/run-local-real-api-ui-tests.sh');
  const args = [
    '--run-ui-tests',
    '--api-root', options['api-root'],
    '--project-dir', projectDir,
    '--derived-data-path', options['derived-data-path'],
    '--test-without-building',
    '--xctestrun', options.xctestrun,
    '--device-id', options['device-id'],
    '--result-bundle', resultPath,
    '--evidence-dir', evidenceDir,
    '--cloned-source-packages-dir', options['cloned-source-packages-dir'],
  ];
  runCommand(helper, args, { stdio: 'inherit' });
  const counts = validateResultBundle(phase, resultPath, runCommand);
  return { resultPath, evidenceDir, count: phase.identifiers.length, counts };
}

function usage() {
  return [
    'Usage: run-appearance-phased-ui-tests.mjs --device-id UDID --xctestrun PATH',
    '  --derived-data-path PATH --results-dir PATH --cloned-source-packages-dir PATH --api-root PATH',
    'Uses one simulator serially: Light UI, local HTTP API UI, Snapshot, then Dark UI.',
    'The previous simulator appearance is restored even when a phase fails.',
    'Reduce Motion is enabled for Snapshot only, then restored to its initial setting.',
  ].join('\n');
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log(usage());
    return;
  }
  verifyInputPaths(options);
  mkdirSync(options['results-dir'], { recursive: true, mode: 0o700 });
  const baseline = readBaselineLedger(resolve(scriptDir, 'appearance-test-baseline.json'));
  const plan = buildAppearancePhasePlan(baseline);
  const phases = plan.phases;
  const results = [];
  const getAppearance = async () => run('xcrun', ['simctl', 'ui', options['device-id'], 'appearance']);
  const setAppearance = async (appearance) => { run('xcrun', ['simctl', 'ui', options['device-id'], 'appearance', appearance]); };
  const getReduceMotion = async () => {
    const value = run('xcrun', ['simctl', 'spawn', options['device-id'], 'defaults', 'read', 'com.apple.Accessibility', 'ReduceMotionEnabled']);
    if (value !== '0' && value !== '1') throw new Error(`Unknown Reduce Motion state: ${value}`);
    return value === '1';
  };
  const setReduceMotion = async (enabled) => {
    run('xcrun', ['simctl', 'spawn', options['device-id'], 'defaults', 'write', 'com.apple.Accessibility', 'ReduceMotionEnabled', '-bool', String(enabled)]);
  };
  const initialMotion = await getReduceMotion();

  const describePlan = {
    baselineTestCount: plan.baselineCount,
    executionCount: plan.executionCount,
    phases: phases.map(({ name, appearance, identifiers }) => ({ name, appearance, reduceMotion: name === 'snapshots' ? true : initialMotion, count: identifiers.length, identifiers })),
  };
  writeFileSync(resolve(options['results-dir'], 'appearance-plan.json'), `${JSON.stringify(describePlan, null, 2)}\n`, { mode: 0o600, flag: 'wx' });

  await runAppearancePhases(phases, {
    getAppearance,
    setAppearance,
    getReduceMotion,
    setReduceMotion,
    runPhase: async (phase) => {
      console.log(`Starting ${phase.name} (${phase.appearance}; ${phase.identifiers.length} selectors).`);
      results.push(phase.kind === 'api-helper'
        ? runAPIPhase(phase, options)
        : runXcodePhase(phase, options, plan));
    },
  });
  const { summary: outcome, exitCode } = summarizeAppearanceResults(results, plan.executionCount);
  const summary = { ...outcome, results };
  writeFileSync(resolve(options['results-dir'], 'appearance-results.json'), `${JSON.stringify(summary, null, 2)}\n`, { mode: 0o600, flag: 'wx' });
  const ordinaryExecutionCount = phases
    .filter(({ kind }) => kind !== 'diagnostic')
    .reduce((count, { identifiers }) => count + identifiers.length, 0);
  console.log(`Completed ${summary.completedExecutions} executions: ${summary.ordinaryPassed}/${ordinaryExecutionCount} ordinary passed; ${summary.diagnosticPassed} diagnostic passed, ${summary.diagnosticFailed} diagnostic failed.`);
  if (exitCode !== 0) process.exitCode = exitCode;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

export { parseArgs, runXcodePhase, runAPIPhase, validateResultBundle };
