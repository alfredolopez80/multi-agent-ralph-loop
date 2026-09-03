> Full text of the global rule ~/.claude/rules/proven/testing-fail-loud-fail-fast.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# testing-fail-loud-fail-fast

ABSOLUTE PRINCIPLE: ALL tests — unit AND e2e — MUST operate on a fail-loud / fail-fast premise, in ANY project. A test exists to surface failure, never to hide it. This applies with special force to heavy e2e tests running against a local minikube cluster.

## Core Premise

- A failing condition MUST make the test FAIL — loudly, immediately, with a clear message.
- The first real assertion failure should stop that test path; do not push past it to "see if the rest works".
- A test that cannot reach a real, meaningful assertion MUST fail — never pass and never silently skip.

## Forbidden in Tests

- `try/catch` (or `try/except`) that swallows an error and lets the test pass anyway
- Soft assertions that only `log`/`print` instead of failing
- `assert True` / no-op assertions / commented-out assertions shipped as "passing"
- `|| true`, `; true`, `continue-on-error: true`, `set +e` used to mask a failing step
- Retry loops that treat "passed on attempt N" as success while hiding chronic flakiness (retries are allowed ONLY when explicitly requested AND the flake is logged loudly)
- Unconditional or broad `skip` / `xfail` / `.only` / `.skip` that hides a real failure
- Catch-and-default: returning a fake "OK" result when the system under test errored

## E2E on Local minikube (special force)

When running heavy e2e tests against a local minikube cluster:

- If minikube is not running, the namespace is missing, an image failed to pull, a pod is not Ready, or a service/endpoint is unreachable → the test MUST FAIL LOUDLY with the concrete reason. NEVER silently skip, NEVER fall back to a mock, NEVER pretend success.
- Do NOT substitute a mock/stub for the real service to "make the suite green" when the cluster is unhealthy — that converts an infra failure into a false pass.
- Readiness waits MUST have a bounded timeout that, on expiry, FAILS the test with the pod/service state (e.g. `kubectl get pods`, `kubectl describe`, recent logs) — not a silent continue.
- Distinguish infra-failure from assertion-failure in the message, but BOTH must fail the test — neither may pass or skip silently.

## Relationship to Other Rules

This is the testing-domain enforcement of `dev-no-unrequested-fallbacks` (fail loud / fail fast by default) and complements `dev-no-production-code-for-tests` (never game production code to pass a test) and `verify-test-expectations` (a wrong test expectation is fixed in the test, not masked).

## Detection Duty (applies even outside the current scope)

If you detect a test that masks failure (any forbidden pattern above) in ANY file — whether or not it is the target of the current analysis, PR, or task — you MUST:

1. Run `git blame` on the offending line(s) to identify when and by whom it was introduced.
2. Report the finding to the user (file, line, blame author/commit, and what failure it is masking).
3. Do NOT silently keep it.

**Trigger**: Authoring, reviewing, or running unit/e2e tests; CI test steps; minikube/k8s e2e suites
**Domain**: testing
**Confidence**: 1.0
**Usage**: 1
