#!/usr/bin/env python3
# VERSION: 2.70.0
# Trigger: PreToolUse (Bash)
# v2.70.0: Cloud CLI coverage (aws/gcloud/gsutil/kubectl) with deny+ask tiers;
#          BLOCKED evaluated before CONFIRMATION; env-var escape hatches can
#          no longer bypass BLOCKED tier (fixes bug introduced in a5faf094)
# v2.69.0: CRIT-002 FIX - Always output JSON for PreToolUse compliance
# v2.66.8: HIGH-003 version sync (fail-closed error handling already implemented)
"""
git-safety-guard.py - Blocks destructive git, filesystem and cloud CLI commands

NOTE: the "git" in the filename is historical - since v2.70.0 this guard also
covers AWS CLI, Google Cloud CLI (gcloud/gsutil) and kubectl.

This hook intercepts Bash commands before execution and blocks potentially
destructive operations that could cause data loss.

Based on: https://github.com/Dicklesworthstone/misc_coding_agent_tips_and_scripts

BLOCKED COMMANDS (permissionDecision "deny" - no escape hatch):
  - git checkout -- <files>     (discards uncommitted changes)
  - git restore <files>         (overwrites working tree)
  - git reset --hard            (destroys uncommitted changes)
  - git reset --merge           (can lose uncommitted changes)
  - git clean -f                (removes untracked files permanently)
  - git branch -D               (force-deletes without merge check)
  - git stash drop / clear      (permanently deletes stash)
  - rm -rf (non-temp dirs)      (recursive deletion)
  - aws: s3 rb --force, s3 rm --recursive, ec2 terminate-instances,
    rds/dynamodb/cloudformation/eks delete, iam delete-*, kms key deletion,
    sqs purge-queue, organizations close-account, ... (see AWS_BLOCKED_PATTERNS)
  - gcloud: projects delete, compute/sql/container delete, storage rm -r,
    kms versions destroy, any delete with --quiet/-q, ... (GCLOUD_BLOCKED_PATTERNS)
  - gsutil: rm -r, rb
  - kubectl: delete namespace, delete --all / -A, delete pv/pvc/crd,
    --grace-period=0, delete/replace --force (KUBECTL_BLOCKED_PATTERNS)

CONFIRMATION COMMANDS (recoverable-destructive):
  - git push --force / -f / +branch  -> deny unless GIT_FORCE_PUSH_CONFIRMED=1
  - aws/gcloud/gsutil/kubectl single-resource deletes (lambda delete-function,
    kubectl delete pod, gcloud functions delete, ...) -> permissionDecision
    "ask" (interactive user prompt), skipped when the matching env var is set:
      AWS_DESTRUCTIVE_CONFIRMED=1      (aws only)
      GCLOUD_DESTRUCTIVE_CONFIRMED=1   (gcloud/gsutil only)
      KUBECTL_DESTRUCTIVE_CONFIRMED=1  (kubectl only)
      CLOUD_DESTRUCTIVE_CONFIRMED=1    (all three cloud CLIs, NOT git)
    Env vars NEVER bypass the BLOCKED tier.

ALLOWED SAFE PATTERNS:
  - git checkout -b, git restore --staged, git clean -n, rm -rf in temp dirs
  - aws describe-*/list-*/get-*, aws s3 ls, sts get-caller-identity
  - gcloud list/describe, gsutil ls/stat/cat
  - kubectl get/describe/logs/top/explain/diff, kubectl delete --dry-run

EXIT CODES:
  0 = Allow command (silent) OR permissionDecision "ask" (JSON on stdout)
  Non-zero with JSON = Block command

INSTALLATION:
  User level:  ~/.claude/hooks/git-safety-guard.py
  Project:     .claude/hooks/git-safety-guard.py

  Add to settings.json:
  {
    "hooks": {
      "PreToolUse": [{
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "~/.claude/hooks/git-safety-guard.py"
        }]
      }]
    }
  }
"""

import json
import os
import re
import shlex
import subprocess
import sys


def normalize_command(command: str) -> str:
    """
    Normalize command for consistent pattern matching.
    Prevents regex bypass via whitespace, quotes, and path variations.
    """
    # Expand environment variables in paths
    command = os.path.expandvars(command)

    # Newlines and carriage returns are UNCONDITIONAL command separators in shell:
    # `git status\ngit restore x` is TWO commands. A blanket `\s+` -> ' ' collapsed them
    # into one fused string, and because is_safe_pattern uses an unanchored search, a safe
    # leading verb (`git status`) then whitened the destructive tail (`git restore`), which
    # never got evaluated. Convert them to `;` so split_chained_commands treats them as the
    # separators they are, then collapse only horizontal whitespace. Splitting a newline
    # that happened to sit inside a quoted string merely over-scrutinises — it fails closed,
    # never open.
    command = re.sub(r"[\r\n]+", " ; ", command)
    command = re.sub(r"[ \t]+", " ", command.strip())

    # Remove common quote variations around paths
    # e.g., rm -rf "/tmp/foo" -> rm -rf /tmp/foo for pattern matching
    command = re.sub(r'["\']([^"\']+)["\']', r"\1", command)

    # Collapse git's GLOBAL options so the subcommand verb sits adjacent to `git`. Every
    # destructive pattern anchors `git\s+<verb>`, so any global flag in between —
    # `git -C other reset --hard`, `git -c k=v clean -fd`, `git -p checkout -- f`,
    # `git -P reset --hard` — slips past all of them. Value-taking globals consume their
    # value; EVERY OTHER leading `-`/`--` token is treated as a valueless global and skipped,
    # so an unenumerated flag (the `-p`/`-P` bypass class found on PR #31) can never break
    # verb adjacency. Git subcommands never start with `-`, so this cannot swallow the verb.
    command = re.sub(
        r"\bgit(?:\s+(?:"
        r"(?:-C|-c|--git-dir|--work-tree|--namespace|--super-prefix|--config-env|--attr-source)"
        r"(?:=\S+|\s+\S+)"
        r"|--exec-path(?:=\S+)?"
        r"|--[A-Za-z][\w-]*"
        r"|-[A-Za-z]+"
        r"))+",
        "git",
        command,
    )

    return command


def log_security_event(event_type: str, command: str, reason: str = ""):
    """Log security events to file (NOT stderr - causes Claude Code hook errors)."""
    import datetime
    import os

    # v2.69.0: Write to file instead of stderr to avoid Claude Code hook error warnings
    log_file = os.path.expanduser("~/.ralph/logs/git-safety-guard.log")
    os.makedirs(os.path.dirname(log_file), exist_ok=True)

    timestamp = datetime.datetime.now().isoformat()
    log_msg = f"[{timestamp}] git-safety-guard: {event_type}"
    if reason:
        log_msg += f" - {reason}"
    log_msg += f" | cmd: {command[:100]}"

    try:
        with open(log_file, "a") as f:
            f.write(log_msg + "\n")
    except Exception:
        pass  # Silently fail logging - don't break hook execution


# ---------------------------------------------------------------------------
# v2.70.0: Anchored CLI prefixes
#
# Cloud patterns are evaluated per-subcommand (after split_chained_commands),
# so ^ anchors to the start of each subcommand. WRAPPER tolerates benign
# wrappers (sudo, env assignments, xargs, ...) but rejects the CLI appearing
# as an argument or inside a string: normalize_command() strips quotes, so
# anchoring is the only reliable defense against false positives like
# `echo "aws s3 rb --force"` or `grep 'gcloud delete' runbook.md`.
WRAPPER = (
    r"^(?:\w+=\S*\s+)*"  # FOO=bar aws ...
    r"(?:(?:sudo|command|nohup|time|nice|env|eval|xargs)\s+(?:-\S+\s+)*(?:\w+=\S*\s+)*)*"
)
# CLI GLOBAL flags sit between the tool name and its subcommand/verb. The destructive
# patterns anchor `tool\s+<verb>`, so ANY unenumerated global flag in between breaks the
# adjacency and silently defeats every block (the `gcloud --project=…`, `kubectl -v=6`
# bypass class found on PR #31). Rather than a fixed allowlist, each prefix now skips a
# leading run of global flags GENERICALLY: value-taking flags are enumerated (so their
# value token is consumed too), and every OTHER leading `-`/`--` token is treated as a
# valueless global and skipped. Subcommands/verbs never start with `-`, so the verb is
# never swallowed. Only LEADING flags are skipped, so a flag appearing after the verb
# (`delete … --quiet`, `s3 ls --query "s3 rb"`) stays in the remainder and never widens
# a match — the anchoring against `echo "aws s3 rb"` (quotes stripped) still holds.
_GLOBAL_TAIL = r"|--[A-Za-z][\w-]*|-[A-Za-z]+)\s+)*"
AWS = (
    WRAPPER + r"aws\s+(?:(?:--(?:profile|region|output|endpoint-url|cli-connect-timeout"
    r"|cli-read-timeout|color|ca-bundle|query|cli-binary-format)(?:=\S+|\s+\S+)" + _GLOBAL_TAIL
)
GCLOUD = (
    WRAPPER + r"gcloud\s+(?:(?:alpha|beta|preview)\s+)?"
    r"(?:(?:--(?:project|account|configuration|verbosity|format|flags-file|billing-project"
    r"|impersonate-service-account|access-token-file)(?:=\S+|\s+\S+)" + _GLOBAL_TAIL
)
GSUTIL = WRAPPER + r"gsutil\s+(?:-[mqD]\s+)*"
KUBECTL = (
    WRAPPER + r"kubectl\s+(?:(?:--(?:context|kubeconfig|namespace|server|token|user|cluster"
    r"|request-timeout|as|as-group|cache-dir|certificate-authority|client-certificate"
    r"|client-key|tls-server-name|v|log-flush-frequency|chunk-size|password|username"
    r"|profile|profile-output)(?:=\S+|\s+\S+)|-[nsuvp](?:=\S+|\s+\S+)" + _GLOBAL_TAIL
)

# Destructive verbs used by the command-substitution / shell -c detectors
DESTRUCTIVE_INNER = (
    r"(?:rm\s|git\s+reset|git\s+clean|git\s+checkout\s+--"
    r"|aws\s+[\w-]+\s+(?:delete|terminate|purge|destroy|remove|deregister)"
    r"|aws\s+s3\s+(?:rm|rb|sync)\b"
    r"|gcloud\s+.*\bdelete\b"
    r"|gsutil\s+(?:rm|rb)\b"
    r"|kubectl\s+(?:delete|drain)\b)"
)

# Patterns that are ALWAYS safe (checked first)
GIT_SAFE_PATTERNS = [
    # Git branching (safe)
    r"git\s+checkout\s+(-b|--orphan)\s+",
    r"git\s+switch\s+(-c|--create)\s+",
    # Git restore staged only (doesn't discard working tree)
    r"git\s+restore\s+--staged\s+",
    # Git clean dry-run (preview only)
    r"git\s+clean\s+.*(-n|--dry-run)",
    # rm in temp directories (ephemeral)
    r"rm\s+(-rf|-fr|--recursive)\s+(/tmp/|/var/tmp/|\$TMPDIR/|/private/tmp/)",
    r"rm\s+(-rf|-fr|--recursive)\s+['\"]?/tmp/",
    r"rm\s+(-rf|-fr|--recursive)\s+['\"]?/var/tmp/",
    # Git status/log/diff (read-only)
    #
    # `branch` carries a negative lookahead: this catch-all is evaluated BEFORE the
    # blocked patterns, so a bare `git branch` entry silently whitelisted
    # `git branch -D` / `--delete --force` and turned the GIT_FS_BLOCKED_PATTERNS rule
    # for it into dead code — while the module docstring claimed it was blocked.
    # Present since the initial commit (f0ec3c1); fixed 2026-07-31.
    r"git\s+(status|log|diff|show|remote|fetch)\b",
    # `(?-i:...)` keeps this case-SENSITIVE even though the caller matches with
    # re.IGNORECASE: `-d` refuses to drop unmerged work and is safe, `-D` forces it.
    r"git\s+branch\b(?!.*(?-i:-[a-zA-Z]*D[a-zA-Z]*\b|-[a-zA-Z]*f[a-zA-Z]*d[a-zA-Z]*\b|-[a-zA-Z]*d[a-zA-Z]*f[a-zA-Z]*\b|--delete(\s+\S+)*\s+--force|--force(\s+\S+)*\s+--delete|-f(\s+\S+)*\s+-d\b|-d(\s+\S+)*\s+-f\b|--force(\s+\S+)*\s+-d\b|-d(\s+\S+)*\s+--force|--delete(\s+\S+)*\s+-f\b|-f(\s+\S+)*\s+--delete))",
    # Git add/commit (safe write operations)
    r"git\s+(add|commit|pull|stash\s+push|stash\s+save)\b",
]

AWS_SAFE_PATTERNS = [
    AWS + r"s3\s+ls\b",
    AWS + r"[\w-]+\s+(?:describe|list|get|head)-[\w-]+",  # describe-*, list-*, get-*, head-*
    AWS + r"sts\s+get-caller-identity\b",
    AWS + r"(?:help\b|--version\b)",
    AWS + r"configure\s+(?:list|get)\b",
]

GCLOUD_SAFE_PATTERNS = [
    # Lookahead keeps `gcloud compute instances delete list` out of SAFE
    GCLOUD + r"(?!.*\bdelete\b)(?:[\w-]+\s+)*(?:list|describe|get-iam-policy)\b",
    GCLOUD + r"config\s+(?:list|get-value)\b",
    GCLOUD + r"(?:auth\s+list|info|version|help)\b",
    GSUTIL + r"(?:ls|stat|cat|du|hash|version)\b",
]

KUBECTL_SAFE_PATTERNS = [
    KUBECTL + r"(?:get|describe|logs|top|explain|version|cluster-info|api-resources|api-versions|diff)\b",
    KUBECTL + r"config\s+(?:view|get-contexts|current-context|use-context)\b",
    KUBECTL + r"delete\b.*--dry-run(?:=(?:client|server))?\b",  # preview only
]

# Patterns that REQUIRE USER CONFIRMATION (risky but allowed with consent)
GIT_CONFIRMATION_PATTERNS = [
    # Force push - risky but sometimes needed
    (
        r"git\s+push\s+.*--force",
        "Force push will overwrite remote history. This can cause issues for collaborators.",
    ),
    (
        r"git\s+push\s+.*-f\b",
        "Force push will overwrite remote history. This can cause issues for collaborators.",
    ),
    (
        r"git\s+push\s+\S+\s+\+",
        "Force push via + prefix will overwrite remote history.",
    ),
]

AWS_CONFIRMATION_PATTERNS = [
    (AWS + r"s3\s+rm\b(?!.*--recursive)", "deletes S3 object(s)"),
    (AWS + r"s3\s+rb\b(?!.*--force)", "removes an (empty) S3 bucket"),
    (AWS + r"s3api\s+delete-object\b", "deletes a single S3 object"),
    (AWS + r"lambda\s+delete-function\b", "deletes Lambda function (usually redeployable)"),
    (AWS + r"logs\s+delete-log-group\b", "deletes CloudWatch log group and its history"),
    (AWS + r"sqs\s+delete-queue\b", "deletes SQS queue"),
    (AWS + r"sns\s+delete-topic\b", "deletes SNS topic and its subscriptions"),
    (
        AWS + r"secretsmanager\s+delete-secret\b",
        "deletes secret (30-day recovery window by default)",
    ),
    (
        AWS + r"ec2\s+delete-(?:security-group|subnet|key-pair|internet-gateway|nat-gateway|route-table)\b",
        "deletes network resource",
    ),
    (AWS + r"ecr\s+batch-delete-image\b", "deletes ECR images"),
    (AWS + r"ecs\s+delete-service\b", "deletes ECS service"),
    (AWS + r"dynamodb\s+delete-item\b", "deletes a DynamoDB item"),
    (AWS + r"cloudfront\s+delete-distribution\b", "deletes CloudFront distribution"),
    # Defensive catch-all: any destructive AWS verb not enumerated above
    (
        AWS + r"[\w-]+\s+(?:delete|remove|terminate|destroy|purge|deregister)-[\w-]+",
        "unrecognized destructive AWS operation (catch-all)",
    ),
]

GCLOUD_CONFIRMATION_PATTERNS = [
    (GCLOUD + r"functions\s+delete\b", "deletes Cloud Function (usually redeployable)"),
    (GCLOUD + r"run\s+services\s+delete\b", "deletes Cloud Run service"),
    (
        GCLOUD + r"pubsub\s+(?:topics|subscriptions)\s+delete\b",
        "deletes Pub/Sub topic/subscription (messages lost)",
    ),
    (
        GCLOUD + r"compute\s+(?:networks|firewall-rules|addresses|routes|routers|forwarding-rules)\s+delete\b",
        "deletes network resource",
    ),
    (GCLOUD + r"storage\s+rm\b", "deletes GCS object(s)"),
    (GSUTIL + r"rm\b", "deletes GCS object(s)"),
    (GCLOUD + r"projects\s+remove-iam-policy-binding\b", "removes IAM policy binding"),
    (GCLOUD + r"app\s+services\s+delete\b", "deletes App Engine service"),
    (
        GCLOUD + r"artifacts\s+(?:repositories|docker\s+images)\s+delete\b",
        "deletes Artifact Registry repository/images",
    ),
    # Defensive catch-all
    (
        GCLOUD + r"[\w-]+(?:\s+[\w-]+)*\s+(?:delete|destroy)\b",
        "unrecognized destructive gcloud operation (catch-all)",
    ),
]

KUBECTL_CONFIRMATION_PATTERNS = [
    (KUBECTL + r"drain\b", "drains a node (evicts all pods)"),
    (KUBECTL + r"delete\s+-f\b", "deletes every resource defined in the manifest"),
    (
        KUBECTL + r"delete\s+(?:pods?|po|deployments?|deploy|services?|svc|configmaps?|cm|secrets?|jobs?|cronjobs?|statefulsets?|sts|daemonsets?|ds|ingress(?:es)?|replicasets?|rs)\b",
        "deletes individual k8s resource (controllers often recreate pods, but confirm)",
    ),
    # Catch-all: any other kubectl delete
    (KUBECTL + r"delete\b", "unrecognized kubectl delete (catch-all)"),
]

# Patterns that are BLOCKED (destructive - no confirmation option)
GIT_FS_BLOCKED_PATTERNS = [
    # Discard uncommitted changes
    (r"git\s+checkout\s+--\s+", "discards uncommitted changes permanently"),
    # Restore without --staged overwrites working tree
    (
        r"git\s+restore\s+(?!--staged).*\S+",
        "overwrites working tree changes without stash",
    ),
    # Hard reset destroys changes
    (r"git\s+reset\s+--hard", "destroys all uncommitted changes permanently"),
    # Merge reset can lose changes
    (r"git\s+reset\s+--merge", "can lose uncommitted changes during merge resolution"),
    # Clean force removes untracked files
    (
        r"git\s+clean\s+.*-f(?!.*(-n|--dry-run))",
        "removes untracked files permanently (use -n first to preview)",
    ),
    # Force delete branch without merge check.
    # Case-sensitive via `(?-i:...)`: the caller matches with re.IGNORECASE, so a plain
    # `-D` pattern also blocked the SAFE `git branch -d`, which refuses to drop unmerged
    # work. Covers the long forms too — `--delete --force` bypassed the old pattern.
    (
        r"git\s+branch\s+(?-i:-[a-zA-Z]*D[a-zA-Z]*\b|-[a-zA-Z]*f[a-zA-Z]*d[a-zA-Z]*\b|-[a-zA-Z]*d[a-zA-Z]*f[a-zA-Z]*\b|--delete(\s+\S+)*\s+--force|--force(\s+\S+)*\s+--delete|-f(\s+\S+)*\s+-d\b|-d(\s+\S+)*\s+-f\b|--force(\s+\S+)*\s+-d\b|-d(\s+\S+)*\s+--force|--delete(\s+\S+)*\s+-f\b|-f(\s+\S+)*\s+--delete)",
        "force-deletes branch without checking if merged",
    ),
    # Stash drop/clear permanently deletes
    (r"git\s+stash\s+drop", "permanently deletes stashed changes"),
    (r"git\s+stash\s+clear", "permanently deletes ALL stashed changes"),
    # VULN-003 FIX: Improved rm -rf protection patterns
    # Block ALL recursive deletes except explicitly allowed temp dirs
    (
        r"rm\s+(-rf|-fr|--recursive)\s+(?!(/tmp/|/var/tmp/|\$TMPDIR/|/private/tmp/))\S",
        "recursive deletion not in safe temp directory",
    ),
    # Block deletion of current directory (extremely dangerous)
    (
        r"rm\s+(-rf|-fr|--recursive)\s+\.\s*$",
        "deletion of current directory is destructive",
    ),
    (
        r"rm\s+(-rf|-fr|--recursive)\s+\.$",
        "deletion of current directory is destructive",
    ),
    # Block relative path deletion with ../
    (
        r"rm\s+(-rf|-fr|--recursive)\s+\.\./",
        "relative path deletion with ../ is unsafe",
    ),
    # Rebase on shared branches (ISSUE-011: removed extra \s+ before branch name)
    (
        r"git\s+rebase\s+.*(main|master|develop)\b",
        "rebasing shared branches can cause issues for collaborators",
    ),
]

AWS_BLOCKED_PATTERNS = [
    # --- S3 / storage ---
    (
        AWS + r"s3\s+rb\b.*--force\b",
        "aws s3 rb --force deletes the bucket AND every object in it, irreversibly",
    ),
    (
        AWS + r"s3\s+rm\b.*--recursive\b",
        "recursive S3 object deletion is irreversible (no trash/versioning guarantee)",
    ),
    (
        AWS + r"s3\s+sync\b.*--delete\b",
        "s3 sync --delete removes destination objects missing from source",
    ),
    (AWS + r"s3api\s+delete-bucket\b", "deletes S3 bucket"),
    (AWS + r"s3api\s+delete-objects\b", "bulk S3 object deletion"),
    # --- Compute ---
    (
        AWS + r"ec2\s+terminate-instances\b",
        "terminates EC2 instances (instance-store data is lost permanently)",
    ),
    (
        AWS + r"ec2\s+delete-(?:volume|snapshot)\b",
        "deletes EBS volume/snapshot (data or backup loss)",
    ),
    (AWS + r"ec2\s+delete-vpc\b", "deletes VPC (cascades to network config)"),
    # --- Databases ---
    (
        AWS + r"rds\s+delete-db-(?:instance|cluster)\b",
        "deletes RDS database (catastrophic with --skip-final-snapshot)",
    ),
    (AWS + r"rds\s+delete-db-(?:cluster-)?snapshot\b", "deletes RDS backup snapshot"),
    (AWS + r"dynamodb\s+delete-table\b", "deletes DynamoDB table and all items"),
    (
        AWS + r"elasticache\s+delete-(?:cache-cluster|replication-group)\b",
        "deletes ElastiCache cluster",
    ),
    (
        AWS + r"redshift\s+delete-cluster\b",
        "deletes Redshift cluster (catastrophic with --skip-final-cluster-snapshot)",
    ),
    # --- IaC / orchestration ---
    (
        AWS + r"cloudformation\s+delete-stack\b",
        "deletes CloudFormation stack and ALL resources it manages",
    ),
    (AWS + r"(?:eks|ecs)\s+delete-cluster\b", "deletes container cluster"),
    # --- IAM / KMS / secrets ---
    (
        AWS + r"iam\s+delete-[\w-]+",
        "deletes IAM entity (user/role/policy/key) - can lock out humans and services",
    ),
    (
        AWS + r"kms\s+(?:schedule-key-deletion|disable-key)\b",
        "KMS key deletion/disable makes all data encrypted with it unreadable",
    ),
    (
        AWS + r"secretsmanager\s+delete-secret\b.*--force-delete-without-recovery\b",
        "deletes secret with NO recovery window",
    ),
    # --- Messaging / DNS / other ---
    (AWS + r"sqs\s+purge-queue\b", "irreversibly purges ALL messages from SQS queue"),
    (AWS + r"route53\s+delete-hosted-zone\b", "deletes DNS hosted zone"),
    (AWS + r"efs\s+delete-file-system\b", "deletes EFS file system and its data"),
    (
        AWS + r"ecr\s+delete-repository\b.*--force\b",
        "deletes ECR repository including all images",
    ),
    (
        AWS + r"backup\s+delete-[\w-]+",
        "deletes AWS Backup recovery points/plans/vaults (destroys backups)",
    ),
    (
        AWS + r"organizations\s+(?:close-account|delete-organization|remove-account-from-organization)\b",
        "account/organization-level destruction",
    ),
]

GCLOUD_BLOCKED_PATTERNS = [
    (
        GCLOUD + r"projects\s+delete\b",
        "deletes the ENTIRE GCP project (all services, 30-day recovery at best)",
    ),
    (
        GCLOUD + r"compute\s+instances\s+delete\b",
        "deletes compute instance(s) including local SSDs",
    ),
    (
        GCLOUD + r"compute\s+(?:disks|snapshots|images)\s+delete\b",
        "deletes disk/snapshot/image (data or backup loss)",
    ),
    (GCLOUD + r"sql\s+instances\s+delete\b", "deletes Cloud SQL instance and databases"),
    (GCLOUD + r"sql\s+backups\s+delete\b", "deletes Cloud SQL backup"),
    (GCLOUD + r"container\s+clusters\s+delete\b", "deletes GKE cluster and all workloads"),
    (
        GCLOUD + r"storage\s+rm\b.*(?:--recursive\b|\s-r\b)",
        "recursive GCS deletion is irreversible",
    ),
    (GCLOUD + r"storage\s+buckets\s+delete\b", "deletes GCS bucket"),
    (GSUTIL + r"rm\b.*(?:\s-[rR]\b|\*\*)", "recursive gsutil deletion is irreversible"),
    (GSUTIL + r"rb\b", "removes GCS bucket"),
    (
        GCLOUD + r"kms\s+keys\s+versions\s+destroy\b",
        "destroys KMS key version (encrypted data becomes unrecoverable)",
    ),
    (
        GCLOUD + r"iam\s+service-accounts\s+delete\b",
        "deletes service account (breaks dependent workloads)",
    ),
    (GCLOUD + r"dns\s+managed-zones\s+delete\b", "deletes DNS managed zone"),
    (GCLOUD + r"firestore\s+databases\s+delete\b", "deletes Firestore database"),
    (GCLOUD + r"(?:bigtable|spanner)\s+instances\s+delete\b", "deletes database instance"),
    # Escalator: --quiet/-q skips gcloud's own interactive confirmation, so any
    # delete carrying it is treated as catastrophic (agents almost always add
    # --quiet because gcloud fails on non-interactive TTYs without it)
    (
        GCLOUD + r"[\w-]+(?:\s+[\w-]+)*\s+delete\b(?=.*(?:\s--quiet\b|\s-q\b))",
        "gcloud delete with --quiet/-q bypasses gcloud's own interactive confirmation",
    ),
]

KUBECTL_BLOCKED_PATTERNS = [
    (
        KUBECTL + r"delete\s+(?:namespaces?|ns)\b",
        "deletes an entire namespace and EVERY resource inside it",
    ),
    (
        KUBECTL + r"delete\b.*--all\b(?!-)",  # (?!-) so --all-namespaces matches its own pattern
        "deletes ALL resources of the given type in the namespace",
    ),
    (
        KUBECTL + r"delete\b.*(?:--all-namespaces\b|\s-A\b)",
        "cluster-wide deletion across all namespaces",
    ),
    (
        KUBECTL + r"delete\s+(?:pv|persistentvolumes?|pvc|persistentvolumeclaims?)\b",
        "deletes persistent volume/claim (underlying data may be reclaimed/destroyed)",
    ),
    (
        KUBECTL + r"delete\s+(?:crd|customresourcedefinitions?)\b",
        "deleting a CRD cascades deletion of all its custom resources",
    ),
    (
        KUBECTL + r"delete\b.*--grace-period(?:=|\s)0\b",
        "grace-period 0 force-deletes without graceful termination",
    ),
    (
        KUBECTL + r"(?:delete|replace)\b.*--force\b",
        "forced deletion/replacement bypasses safeguards",
    ),
]

# Aggregates - names preserved so check_* functions and legacy tests are untouched
SAFE_PATTERNS = (
    GIT_SAFE_PATTERNS + AWS_SAFE_PATTERNS + GCLOUD_SAFE_PATTERNS + KUBECTL_SAFE_PATTERNS
)
BLOCKED_PATTERNS = (
    GIT_FS_BLOCKED_PATTERNS
    + AWS_BLOCKED_PATTERNS
    + GCLOUD_BLOCKED_PATTERNS
    + KUBECTL_BLOCKED_PATTERNS
)
CONFIRMATION_PATTERNS = (
    GIT_CONFIRMATION_PATTERNS
    + AWS_CONFIRMATION_PATTERNS
    + GCLOUD_CONFIRMATION_PATTERNS
    + KUBECTL_CONFIRMATION_PATTERNS
)

# Confirmation groups: (patterns, env vars that pre-approve them, decision).
# Env vars only ever skip the CONFIRMATION tier - BLOCKED has no escape hatch.
# CLOUD_DESTRUCTIVE_CONFIRMED covers the three cloud CLIs but NOT git.
CONFIRMATION_GROUPS = [
    (GIT_CONFIRMATION_PATTERNS, ("GIT_FORCE_PUSH_CONFIRMED",), "deny"),
    (AWS_CONFIRMATION_PATTERNS, ("AWS_DESTRUCTIVE_CONFIRMED", "CLOUD_DESTRUCTIVE_CONFIRMED"), "ask"),
    (GCLOUD_CONFIRMATION_PATTERNS, ("GCLOUD_DESTRUCTIVE_CONFIRMED", "CLOUD_DESTRUCTIVE_CONFIRMED"), "ask"),
    (KUBECTL_CONFIRMATION_PATTERNS, ("KUBECTL_DESTRUCTIVE_CONFIRMED", "CLOUD_DESTRUCTIVE_CONFIRMED"), "ask"),
]


def is_safe_pattern(command: str) -> bool:
    """Check if command matches a known safe pattern."""
    for pattern in SAFE_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return True
    return False


def check_confirmation_pattern_ex(command: str) -> tuple[bool, str, str]:
    """Check confirmation patterns honoring per-group env-var escape hatches.

    Returns (needs_confirm, reason, decision) where decision is "deny"
    (legacy git behavior) or "ask" (cloud CLIs, interactive user prompt).
    If a matching group's env var is set to "1" the match is pre-approved
    and (False, "", "") is returned. BLOCKED patterns are NOT consulted
    here - env vars can never bypass the BLOCKED tier.
    """
    for patterns, env_vars, decision in CONFIRMATION_GROUPS:
        for pattern, reason in patterns:
            if re.search(pattern, command, re.IGNORECASE):
                if any(os.environ.get(var) == "1" for var in env_vars):
                    log_security_event(
                        "ALLOWED_CONFIRMED",
                        command,
                        f"User pre-confirmed via env var ({reason})",
                    )
                    return False, "", ""
                return True, reason, decision
    return False, "", ""


def check_confirmation_pattern(command: str) -> tuple[bool, str]:
    """Check if command requires user confirmation. Returns (needs_confirm, reason)."""
    needs_confirm, reason, _decision = check_confirmation_pattern_ex(command)
    return needs_confirm, reason


# `git restore` / `git checkout --` on a file that is DELETED in the working tree
# destroys nothing: the content is intact in HEAD and the only thing reverted is the
# deletion itself. On a MODIFIED file the same command wipes edits that exist nowhere
# else (no reflog covers the working tree), which is why the block stays for those.
RESTORE_LIKE = re.compile(
    r"^\s*git\s+(?:restore|checkout\s+--)\s+(?P<targets>.+)$", re.IGNORECASE
)


# A trackable `cd`: bare (→ $HOME) or exactly one target token. Anything else — a target
# that needed quoting (normalize_command strips the quotes, so `cd "a b"` arrives as the
# three-token `cd a b`), an option like `-P`/`-L`, or `cd -` — is NOT trackable here.
CD_RE = re.compile(r"^\s*cd(?:\s+(?P<target>\S+))?\s*$")
# Wrappers that still run the following builtin in the CURRENT shell, so `<wrapper> cd DIR`
# moves the shell. They can stack (`command eval cd`), carry a leading backslash
# (`\command cd`), carry their own options (`command -p cd`, `time -p cd`), and the whole
# thing may sit inside a brace group (`{ cd DIR; }`). `cd`/`pushd`/`popd` itself may be
# escaped (`\cd`). Enumerating a fixed depth is a losing game — any bound is beaten by more
# wrappers — so exhaustion is treated as a directory change and fails closed (see below).
CD_WRAPPER_RE = re.compile(r"^\s*(?:\{\s*)*\\?(?:command|builtin|eval|time)(?:\s+-\S+)*\s+")
CD_HEAD_RE = re.compile(r"^\s*(?:\{\s*)*\\?(?:cd|pushd|popd)\b")
_CD_STRIP_BOUND = 12

# Constructs that can relocate the shell OPAQUELY — the guard cannot see where they land,
# so the restore-of-deleted exemption must not be trusted after them: sourcing a file
# (`.`/`source`, incl. `. <(...)`) whose contents may `cd`; a function definition
# (`f(){ ... }`) whose later call may `cd`; and `eval` of DYNAMIC content (`eval "$(...)"`,
# `eval "$VAR"`) whose expansion may `cd` — a literal `eval cd DIR` is still tracked by
# _is_directory_change, but `eval` over a command/variable substitution is unknowable.
# apply_cd returns "" for these so the exemption fails closed rather than judging a restore
# against a possibly-stale directory.
_OPAQUE_RELOCATOR_RE = re.compile(
    r"^\s*(?:\.|source)\s"          # sourcing a file
    r"|[A-Za-z_]\w*\s*\(\s*\)"      # a function definition
    r"|\beval\b[^;&|]*[$`]"         # eval over a $(...) / `...` / $VAR expansion
)


def _is_directory_change(subcmd: str) -> bool:
    """True if the subcommand ultimately runs cd/pushd/popd in the current shell.

    Peels shell-builtin wrappers (with their options, an optional leading `{`, a backslash)
    one at a time, checking for the builtin at each step, so `time -p cd`, `\\command cd`,
    `command eval cd` and `{ cd X; }` are all recognised. If the input is STILL wrapped after
    the bound — a pathological `eval`×N stack we cannot see through — that counts as a
    directory change too, so apply_cd fails closed rather than assuming the stale cwd. The
    only way to return False is to settle on a concrete non-cd token within the bound.
    """
    s = subcmd
    for _ in range(_CD_STRIP_BOUND):
        if CD_HEAD_RE.match(s):
            return True
        m = CD_WRAPPER_RE.match(s)
        if not m:
            return False  # settled on a real, non-cd command → genuinely not a dir change
        s = s[m.end():]
    return True  # still peeling wrappers past the bound — unresolvable, so fail closed


def apply_cd(subcmd: str, cwd: str) -> str:
    """The directory the NEXT subcommand runs in, after honouring a leading `cd`.

    `cd` is a routine worktree operation and is never blocked. What it changes is WHERE
    a later subcommand acts: `cd other-repo && git restore f.txt` must be judged against
    other-repo's working tree, not the payload's cwd. Evaluating in the wrong repository
    once allowed a restore that destroyed uncommitted edits.

    A subcommand that does NOT change directory returns `cwd` unchanged. A directory
    change this function cannot resolve with confidence — `popd`, `pushd`, `cd -`, a
    quoted/spaced/optioned target, an unreadable path — returns "". Callers treat an
    empty cwd as doubt and fail closed (they withhold a restore exemption; they never
    block the `cd` itself). Returning the STALE cwd here instead would fail OPEN: the
    later `git restore` would be judged against the directory the shell already left.
    """
    if _OPAQUE_RELOCATOR_RE.search(subcmd):
        return ""  # sourcing / a function definition can relocate the shell — fail closed
    if not _is_directory_change(subcmd):
        return cwd  # not a directory change — the next subcommand still runs in cwd
    match = CD_RE.match(subcmd)
    if not match:
        return ""  # a wrapped/escaped/multi-token cd we cannot track — fail closed
    target = (match.group("target") or "~").strip("\"'")
    if target == "-":
        return ""  # previous directory — not tracked
    target = os.path.expanduser(os.path.expandvars(target))
    if not target or target.startswith("$"):
        return ""  # an unresolved variable expansion — fail closed
    destination = target if os.path.isabs(target) else os.path.join(cwd or "", target)
    return os.path.normpath(destination) if destination else ""


def _restore_targets_are_all_deleted(command: str, cwd: str) -> bool:
    """True when every path in a restore-like command is deleted in the working tree.

    Returns False on any doubt — no targets, an unreadable repo, a non-zero git exit,
    or a single path that is not deleted. The guard must fail closed.

    `cwd` is the EFFECTIVE directory for this subcommand (see `apply_cd`), so a chain
    that changes directory is judged against the repository it actually lands in.
    """
    if not cwd or not os.path.isdir(cwd):
        return False
    match = RESTORE_LIKE.match(command)
    if not match:
        return False

    targets = [
        token
        for token in shlex.split(match.group("targets"))
        if not token.startswith("-")
    ]
    if not targets:
        return False

    try:
        result = subprocess.run(
            ["git", "status", "--porcelain", "--"] + targets,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    if result.returncode != 0:
        return False

    lines = [line for line in result.stdout.splitlines() if line.strip()]
    # One status line per target, and every one of them must report a deletion.
    if len(lines) != len(targets):
        return False
    return all(line[:2] in (" D", "D ", "DD") for line in lines)


def safe_alternative(command: str) -> str:
    """A concrete non-destructive command to run instead, or "" when none applies.

    Escalating to "ask the user to run it manually" is not a plan: it leaves the caller
    with no way forward. Where a safe route exists, name it.
    """
    if RESTORE_LIKE.match(command):
        return (
            "SAFE ALTERNATIVE: preserve the changes first, then restore — "
            "`git stash push -- <files>` followed by the restore. "
        )
    if re.search(r"git\s+reset\s+--hard", command, re.IGNORECASE):
        return (
            "SAFE ALTERNATIVE: `git stash push -u` keeps the working tree recoverable; "
            "commits stay reachable via `git reflog`. "
        )
    if re.search(r"git\s+clean\s+.*-f", command, re.IGNORECASE):
        return "SAFE ALTERNATIVE: run `git clean -n` first to preview what would be removed. "
    if re.search(r"git\s+branch\s+-D\s+", command, re.IGNORECASE):
        return "SAFE ALTERNATIVE: `git branch -d` refuses to drop unmerged work. "
    return ""


def check_blocked_pattern(command: str, cwd: str = "") -> tuple[bool, str]:
    """Check if command matches a blocked pattern. Returns (blocked, reason).

    `cwd` is the effective directory for this subcommand, so a chain that changes
    directory is judged against the repository it actually lands in.
    """
    for pattern, reason in BLOCKED_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            if RESTORE_LIKE.match(command) and _restore_targets_are_all_deleted(command, cwd):
                continue  # recovering a deleted file — nothing to overwrite
            return True, reason
    return False, ""


def split_chained_commands(command: str) -> list[str]:
    """Split a command string by shell chaining operators (&&, ||, ;, |).

    SEC-1.6: Detects command chaining to prevent bypass of safety checks
    via patterns like 'echo safe && rm -rf /' or 'ls ; git reset --hard'.
    """
    # Split on every shell command separator: &&, ||, ;, |, newline, AND a background `&`.
    # A background `&` runs the NEXT command too (`git status & git reset --hard` executes
    # the reset), so a safe leading verb must not whiten the tail after it. The lone-`&`
    # branch excludes redirect operators via look-around: `2>&1`, `&>file`, `<&3` keep their
    # `&`. `&&` is matched by its own alternative first, so it never reaches the lone branch.
    parts = re.split(r'\s*(?:&&|\|\||[;|\n]|(?<![<>&])&(?![<>&]))\s*', command)
    return [p.strip() for p in parts if p.strip()]


def allow_and_exit():
    """CRIT-002 FIX: Always output JSON for PreToolUse compliance."""
    print('{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}')
    sys.exit(0)


def main():
    original_command = ""
    hook_input = None

    try:
        # Read hook input from stdin
        input_data = sys.stdin.read()
        if not input_data.strip():
            allow_and_exit()  # No input, allow

        try:
            hook_input = json.loads(input_data)
        except json.JSONDecodeError as e:
            # Invalid JSON, allow (not a valid hook input)
            log_security_event("json_error", "invalid", f"Invalid JSON in hook input: {e}")
            allow_and_exit()

        # Only process Bash tool calls
        tool_name = hook_input.get("tool_name", "")
        if tool_name != "Bash":
            allow_and_exit()  # Not Bash, allow

        # Extract the command
        tool_input = hook_input.get("tool_input", {})
        original_command = tool_input.get("command", "")

        if not original_command:
            allow_and_exit()  # No command, allow

        # Needed to inspect working-tree state: `git restore` on a DELETED file is
        # harmless, on a MODIFIED one it is irreversible. Only git can tell them apart.
        hook_cwd = hook_input.get("cwd", "") or os.getcwd()

        # SECURITY: Normalize command to prevent regex bypass
        command = normalize_command(original_command)

        # BUG-007 FIX: Detect command substitution patterns ($(...) and backticks)
        # These can hide destructive commands inside seemingly safe ones
        # v2.70.0: DESTRUCTIVE_INNER also covers aws/gcloud/gsutil/kubectl verbs
        if re.search(r'\$\(.*' + DESTRUCTIVE_INNER, command) or \
           re.search(r'`.*' + DESTRUCTIVE_INNER, command):
            log_security_event("BLOCKED", original_command, "Command substitution with destructive command detected")
            response = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": f"BLOCKED by git-safety-guard: Command substitution detected with destructive command. "
                    f"Command: {original_command[:100]}{'...' if len(original_command) > 100 else ''}. "
                    f"Remove the $() or backtick wrapper and run the inner command separately.",
                }
            }
            print(json.dumps(response))
            sys.exit(1)

        # v2.70.0: Detect shell -c wrappers hiding destructive commands
        # (normalize_command strips quotes, so `bash -c "aws s3 rb --force ..."`
        # arrives as `bash -c aws s3 rb --force ...` and would otherwise bypass
        # the anchored CLI prefixes)
        if re.search(r'(?:^|\s)(?:ba|z|da)?sh\s+(?:-\w+\s+)*-c\s+.*' + DESTRUCTIVE_INNER, command):
            log_security_event("BLOCKED", original_command, "shell -c wrapper with destructive command detected")
            response = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": f"BLOCKED by git-safety-guard: shell -c wrapper detected with destructive command. "
                    f"Command: {original_command[:100]}{'...' if len(original_command) > 100 else ''}. "
                    f"Remove the sh -c wrapper and run the inner command directly.",
                }
            }
            print(json.dumps(response))
            sys.exit(1)

        # SEC-1.6: Split by chaining operators and check EACH subcommand
        subcommands = split_chained_commands(command)

        # If there are multiple subcommands, check each one individually
        # A chained command is only safe if ALL subcommands are safe
        #
        # `cd` is tracked as the chain is walked so each subcommand is judged against the
        # directory it really runs in. Worktree work is full of `cd <worktree> && git ...`,
        # and treating the payload's cwd as the destination misjudged those. The tracking
        # happens BEFORE the safe-pattern check because `cd` is itself a safe pattern and
        # would otherwise skip the loop body.
        effective_cwd = hook_cwd
        for subcmd in subcommands:
            subcmd_normalized = normalize_command(subcmd)
            effective_cwd = apply_cd(subcmd_normalized, effective_cwd)

            # A git op retargeted with -C/--git-dir/--work-tree acts on a DIFFERENT working
            # tree than cwd. normalize_command strips those flags so the destructive verbs
            # (reset/clean/branch -D/…) match and block; but for `git restore`, whose only
            # allow-path is the deleted-file exemption, judging the payload's cwd would be
            # wrong (the file may be modified in the -C tree). Mark cwd untrustworthy so the
            # exemption fails closed for any retargeted git command.
            if re.search(r"\bgit\b(?=.*\s(?:-C\b|--git-dir\b|--work-tree\b))", subcmd):
                effective_cwd = ""

            # Check safe patterns first (skip to next subcommand if safe)
            if is_safe_pattern(subcmd_normalized):
                continue

            # v2.70.0: BLOCKED is checked FIRST so hard blocks can never be
            # shadowed by confirmation catch-alls nor bypassed via env vars
            # (fixes pre-existing bug where GIT_FORCE_PUSH_CONFIRMED=1
            # disabled the entire guard, commit a5faf094)
            blocked, reason = check_blocked_pattern(subcmd_normalized, effective_cwd)

            if blocked:
                log_security_event("BLOCKED", original_command, f"Chained command contains: {reason}")
                response = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": f"BLOCKED by git-safety-guard: Command chaining detected. "
                        f"Dangerous subcommand found: {subcmd_normalized[:80]}. "
                        f"Reason: {reason}. "
                        f"Command: {original_command[:100]}{'...' if len(original_command) > 100 else ''}. "
                        f"{safe_alternative(subcmd_normalized)}"
                        f"If truly needed, ask the user to run it manually.",
                    }
                }
                print(json.dumps(response))
                sys.exit(1)

            # Check confirmation patterns (require user consent); env-var
            # escape hatches are honored inside check_confirmation_pattern_ex
            needs_confirm, confirm_reason, confirm_decision = check_confirmation_pattern_ex(
                subcmd_normalized
            )

            if needs_confirm:
                if confirm_decision == "ask":
                    # Cloud CLIs: hand the decision to the user via the native
                    # permission prompt. JSON is only processed on exit 0.
                    log_security_event(
                        "NEEDS_CONFIRMATION", original_command, f"Ask user: {confirm_reason}"
                    )
                    response = {
                        "hookSpecificOutput": {
                            "hookEventName": "PreToolUse",
                            "permissionDecision": "ask",
                            "permissionDecisionReason": f"git-safety-guard: destructive cloud CLI operation. "
                            f"Subcommand: {subcmd_normalized[:80]}. "
                            f"Reason: {confirm_reason}. "
                            f"For unattended automation set AWS_/GCLOUD_/KUBECTL_/CLOUD_DESTRUCTIVE_CONFIRMED=1.",
                        }
                    }
                    print(json.dumps(response))
                    sys.exit(0)

                # Legacy git behavior: deny with env-var escape hatch
                log_security_event("NEEDS_CONFIRMATION", original_command, f"Chained command contains: {confirm_reason}")
                response = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": f"BLOCKED by git-safety-guard: Command chaining detected. "
                        f"Dangerous subcommand found: {subcmd_normalized[:80]}. "
                        f"Reason: {confirm_reason}. "
                        f"Command: {original_command[:100]}{'...' if len(original_command) > 100 else ''}. "
                        f"Split into separate commands for safety.",
                    }
                }
                print(json.dumps(response))
                sys.exit(1)

        # All subcommands passed - allow (CRIT-002: output JSON for compliance)
        allow_and_exit()

    except json.JSONDecodeError as e:
        # SECURITY: Fail-closed on invalid JSON (could be injection attempt)
        log_security_event(
            "BLOCKED", original_command or "<unknown>", f"Invalid JSON input: {e}"
        )
        response = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "git-safety-guard: Invalid input format. Command blocked for safety.",
            }
        }
        print(json.dumps(response))
        sys.exit(1)
    except Exception as e:
        # SECURITY: Fail-closed on unexpected errors (safer default)
        log_security_event(
            "BLOCKED", original_command or "<unknown>", f"Unexpected error: {e}"
        )
        response = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": f"git-safety-guard: Internal error, command blocked for safety. Error: {e}",
            }
        }
        print(json.dumps(response))
        sys.exit(1)


if __name__ == "__main__":
    main()
