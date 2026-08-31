"""gcloud deploy-verbs regression runner (issue #70, PR3-C6).

The issue #70 gap: `gcloud app deploy` was silently allowed. This suite pins
the explicit deploy/mutate verb list gated at the CONFIRMATION tier (ask), the
harmless reads that must stay allow-listed, both documented escape hatches
(GCLOUD_DESTRUCTIVE_CONFIRMED / CLOUD_DESTRUCTIVE_CONFIRMED), the untouched
existing protections, and the unclassified-by-design behavior for a fresh verb
not on the list (no catch-all by mandate — a broad one would sweep reads).

Fail-loud: every case asserts the exact decision; the run fails unless
>= MIN_CASES cases executed with zero failures (zero-tests-is-never-success).
"""

import json
import os
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[3]
GUARD = PROJECT_ROOT / ".claude" / "hooks" / "git-safety-guard.py"

MIN_CASES = 17
ran = passed = failed = xfailed = 0


def decision(command, extra_env=None):
    env = {k: v for k, v in os.environ.items() if "DESTRUCTIVE_CONFIRMED" not in k}
    env.update(extra_env or {})
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": "/tmp"})
    p = subprocess.run(["python3", str(GUARD)], input=payload, text=True, capture_output=True, env=env)
    return json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]


def check(name, got, ok, detail=""):
    global ran, passed, failed
    ran += 1
    if ok:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}: {detail or got}")


# --- (1) Explicit deploy/mutate verbs -> gated (ask) — one fixture per verb ---
DEPLOY_VERBS = [
    ("gcloud app deploy", "app_deploy_gated_ask"),
    ("gcloud run deploy", "run_deploy_gated_ask"),
    ("gcloud functions deploy", "functions_deploy_gated_ask"),
    ("gcloud firebase deploy", "firebase_deploy_gated_ask"),
    (
        "gcloud compute instance-groups managed rolling-action start mygroup",
        "rolling_action_start_gated_ask",
    ),
    ("gcloud app versions stop v2 --service svc", "app_versions_stop_gated_ask"),
    ("gcloud app versions start v2", "app_versions_start_gated_ask"),
    # Release-channel prefix must not dodge the gate (GCLOUD regex covers it).
    ("gcloud beta run deploy", "beta_channel_run_deploy_gated_ask"),
]
for command, name in DEPLOY_VERBS:
    check(name, decision(command), decision(command) == "ask", f"decision={decision(command)}")

# --- (2) Harmless gcloud reads remain allow-listed ---
READS = [
    ("gcloud app describe", "app_describe_still_allowed"),
    ("gcloud app versions list", "app_versions_list_still_allowed"),
    ("gcloud run services describe srv", "run_services_describe_still_allowed"),
]
for command, name in READS:
    check(name, decision(command), decision(command) == "allow", f"decision={decision(command)}")

# --- (3) Documented escape hatches: pre-confirmation env vars (both of the group) ---
check(
    "escape_hatch_gcloud_confirmed_allows",
    decision("gcloud app deploy", {"GCLOUD_DESTRUCTIVE_CONFIRMED": "1"}),
    decision("gcloud app deploy", {"GCLOUD_DESTRUCTIVE_CONFIRMED": "1"}) == "allow",
    "GCLOUD_DESTRUCTIVE_CONFIRMED=1 must skip the CONFIRMATION tier",
)
check(
    "escape_hatch_cloud_confirmed_allows",
    decision("gcloud app deploy", {"CLOUD_DESTRUCTIVE_CONFIRMED": "1"}),
    decision("gcloud app deploy", {"CLOUD_DESTRUCTIVE_CONFIRMED": "1"}) == "allow",
    "CLOUD_DESTRUCTIVE_CONFIRMED=1 must skip the CONFIRMATION tier",
)

# --- (4) Existing aws/terraform/gcloud protections unchanged ---
check(
    "existing_gcloud_delete_still_ask",
    decision("gcloud functions delete fn"),
    decision("gcloud functions delete fn") == "ask",
    f"decision={decision('gcloud functions delete fn')}",
)
check(
    "existing_gcloud_storage_rm_still_ask",
    decision("gcloud storage rm bucket/obj"),
    decision("gcloud storage rm bucket/obj") == "ask",
    f"decision={decision('gcloud storage rm bucket/obj')}",
)
check(
    "existing_aws_terminate_still_deny",
    decision("aws ec2 terminate-instances i-123"),
    decision("aws ec2 terminate-instances i-123") == "deny",
    f"decision={decision('aws ec2 terminate-instances i-123')}",
)

# --- (5) Fresh verb NOT on the list: unclassified by design (no catch-all) ---
# Mandate of the PR3-C6 brief: a broad deploy catch-all would sweep harmless
# reads. A fresh deploy verb is the documented fail-open trade-off — this case
# PINS the current design so a silent change to it is caught by this suite.
check(
    "fresh_verb_unclassified_by_design",
    decision("gcloud compute deployments create x"),
    decision("gcloud compute deployments create x") == "allow",
    f"decision={decision('gcloud compute deployments create x')} (design changed: re-triage)",
)

print()
print(f"RAN={ran}  PASS={passed}  FAIL={failed}  XFAIL={xfailed}")
# "Passed: N | ..." is the summary format tests/run-all-unit-tests.sh parses for an
# assertion count (strategy 1); keep it in sync if this line ever changes.
print(f"Passed: {passed} | Failed: {failed} | Xfail: {xfailed}")
if failed > 0 or ran < MIN_CASES:
    print(f"FAIL: expected >= {MIN_CASES} executed cases with zero failures")
    sys.exit(1)
