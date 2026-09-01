import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// A JSON report over a large diff can exceed spawnSync's 1 MiB default.
const SPAWN_MAX_BUFFER_BYTES = 16 * 1024 * 1024;

// The schema this hook reads. react-doctor stamps every report with its own
// schemaVersion; a bump means the field names below may have moved.
const SUPPORTED_SCHEMA_VERSION = 3;

// Reporting every warning on every edit batch is noise. Interrupt only for
// errors and for anything the tool categorises as a security problem.
const REPORTED_CATEGORIES = new Set(['Security']);

// Keeps the injected context bounded on a repo with a long tail of findings.
const MAX_REPORTED_DIAGNOSTICS = 20;

const EDIT_TOOL_NAMES = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit', 'ApplyPatch']);

const readFileOrEmpty = (source) => {
  try {
    return readFileSync(source, 'utf8');
  } catch {
    return '';
  }
};

// This hook is registered globally, so it fires in repos that have no JavaScript
// at all. There react-doctor exits non-zero with "No React project found", which
// the reporting path below would present as a code-quality finding.
//
// Applicability narrowed to TypeScript projects (user decision 2026-09-01): this
// hook exists to surface CODE-QUALITY improvements (React correctness errors and
// security findings — the only categories reported below), not to duplicate what
// eslint/prettier already cover; styling lint never reaches the report path.
// A JS-but-not-TS project is out of scope by the same decision.
const looksLikeTsProject = () => {
  if (!existsSync('package.json')) return false;
  if (existsSync('tsconfig.json')) return true;
  try {
    const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
    const deps = { ...pkg.dependencies, ...pkg.devDependencies };
    return Boolean(deps.typescript);
  } catch {
    return false;
  }
};

const shouldScan = (input) => {
  const eventName = input.hook_event_name || input.eventName || input.event_name;
  if (eventName === 'PostToolBatch') {
    const toolCalls = Array.isArray(input.tool_calls) ? input.tool_calls : [];
    return toolCalls.some((toolCall) => EDIT_TOOL_NAMES.has(toolCall.tool_name));
  }
  const toolName = input.tool_name || input.toolName || input.tool;
  return !toolName || EDIT_TOOL_NAMES.has(toolName);
};

// Returns react-doctor's parsed report, or null when no runner produced one.
//
// The exit code is deliberately ignored. react-doctor exits non-zero both when it
// finds problems and when it cannot run at all ("No React project found"), and the
// package managers below exit non-zero for registry, auth, TLS and offline errors.
// Reading the code conflates all of that; the report separates it: `error` carries
// setup failures, `diagnostics` carries findings. `--json` also suppresses every
// other kind of output, so stderr can no longer contaminate what we report.
const runReactDoctor = () => {
  // Each candidate is a single shell command string (not an args array):
  // `shell: true` is required to run the Windows `.cmd` shims, and an args
  // array with `shell: true` trips Node's DEP0190. A missing command exits
  // 127 via a POSIX shell (no ENOENT error) and 9009 via cmd.exe, so fall
  // through on those. The local bin is probed with existsSync (its `./`
  // prefix form is not runnable by cmd.exe at all).
  const localBin = process.platform === 'win32'
    ? 'node_modules\\.bin\\react-doctor.cmd'
    : './node_modules/.bin/react-doctor';
  const flags = ' --json --json-compact --scope changed --no-score';
  const commands = [
    ...(existsSync(localBin) ? [localBin + flags] : []),
    'react-doctor' + flags,
    'pnpm dlx react-doctor@latest' + flags,
    'npx --yes react-doctor@latest' + flags,
  ];

  for (const command of commands) {
    const result = spawnSync(command, { encoding: 'utf8', shell: true, maxBuffer: SPAWN_MAX_BUFFER_BYTES });
    if (result.error?.code === 'ENOENT' || result.status === 127 || result.status === 9009) continue;
    const stdout = (result.stdout || '').trim();
    // No report on stdout means this runner never got as far as the tool, whatever
    // its exit code: try the next one rather than treating the failure as a finding.
    if (!stdout) continue;
    try {
      return JSON.parse(stdout);
    } catch {
      continue;
    }
  }

  return null;
};

// Findings worth interrupting for, most severe first.
const reportableDiagnostics = (report) => {
  const all = Array.isArray(report.diagnostics) ? report.diagnostics : [];
  return all
    .filter((d) => d && (d.severity === 'error' || REPORTED_CATEGORIES.has(d.category)))
    .sort((a, b) => (a.severity === b.severity ? 0 : a.severity === 'error' ? -1 : 1));
};

const formatDiagnostic = (d) => {
  const where = [d.filePath, d.line || null, d.column || null].filter(Boolean).join(':');
  const head = `${d.severity || 'warning'}  ${where}  ${d.rule || 'unknown-rule'}`;
  const lines = [head, `    ${d.message || ''}`.trimEnd()];
  if (d.help) lines.push(`    help: ${d.help}`);
  return lines.join('\n');
};

const main = () => {
  let input;
  try {
    input = JSON.parse(readFileOrEmpty(0) || '{}');
  } catch {
    input = {};
  }

  if (!shouldScan(input)) {
    process.exit(0);
  }

  const projectRoot = process.env.CLAUDE_PROJECT_DIR || join(__dirname, '../..');

  try {
    process.chdir(projectRoot);
  } catch {
    process.exit(0);
  }

  // REACT_DOCTOR_SELFTEST=1 prints the applicability verdict instead of running
  // the scan — lets CI and registration checks verify the guard without network,
  // react-doctor itself, or a React project (the three reasons a real run exits 0).
  if (process.env.REACT_DOCTOR_SELFTEST) {
    console.log(`selftest: ts-project=${looksLikeTsProject() ? 'yes' : 'no'} cwd=${process.cwd()}`);
    process.exit(0);
  }

  if (!looksLikeTsProject()) {
    process.exit(0);
  }

  const report = runReactDoctor();
  // No runner produced a report, the tool could not run (no React project, bad
  // config), or the schema moved under us: none of those are code-quality findings.
  if (!report || report.error || report.schemaVersion !== SUPPORTED_SCHEMA_VERSION) {
    process.exit(0);
  }

  const diagnostics = reportableDiagnostics(report);
  if (diagnostics.length === 0) {
    process.exit(0);
  }

  const shown = diagnostics.slice(0, MAX_REPORTED_DIAGNOSTICS);
  const omitted = diagnostics.length - shown.length;
  const body = shown.map(formatDiagnostic).join('\n\n')
    + (omitted > 0 ? `\n\n... and ${omitted} more.` : '');

  const message = `React Doctor found ${diagnostics.length} issue(s) in the changed files (errors and security findings only). Review this output and fix the regressions before finishing. For confirmed issues that cannot be fixed now, create GitHub issues with the rule, file/line, confidence, impact, and proposed fix.\n\n${body}`;

  if (input.hook_event_name === 'PostToolBatch') {
    console.log(JSON.stringify({ hookSpecificOutput: { hookEventName: 'PostToolBatch', additionalContext: message } }));
  } else {
    console.log(JSON.stringify({ additional_context: message }));
  }
};

main();