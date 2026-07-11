#!/usr/bin/env python3
"""
Unit tests for the cloud CLI coverage of git-safety-guard.py (v2.70.0)

Covers AWS CLI, gcloud/gsutil and kubectl destructive-command detection:
BLOCKED (deny), CONFIRMATION (ask), SAFE, bypass prevention, false
positives and env-var escape hatches.

Run with: pytest tests/test_cloud_safety_guard.py -v
"""

import json
import os
import sys
import pytest
from io import StringIO
from unittest.mock import patch

# Add the hooks directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".claude", "hooks"))

# Import the module under test
import importlib.util

spec = importlib.util.spec_from_file_location(
    "git_safety_guard",
    os.path.join(
        os.path.dirname(__file__), "..", ".claude", "hooks", "git-safety-guard.py"
    ),
)
git_safety_guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(git_safety_guard)

ESCAPE_HATCH_VARS = [
    "GIT_FORCE_PUSH_CONFIRMED",
    "AWS_DESTRUCTIVE_CONFIRMED",
    "GCLOUD_DESTRUCTIVE_CONFIRMED",
    "KUBECTL_DESTRUCTIVE_CONFIRMED",
    "CLOUD_DESTRUCTIVE_CONFIRMED",
]


@pytest.fixture(autouse=True)
def clean_escape_hatches(monkeypatch):
    """Escape-hatch env vars must not leak between tests."""
    for var in ESCAPE_HATCH_VARS:
        monkeypatch.delenv(var, raising=False)


def create_hook_input(command: str) -> str:
    """JSON input as provided by the Claude Code hook system."""
    return json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})


def run_main(command: str):
    """Run main() with the command on stdin. Returns (exit_code, parsed_json)."""
    with patch("sys.stdin", StringIO(create_hook_input(command))):
        with pytest.raises(SystemExit) as exc_info:
            git_safety_guard.main()
    return exc_info.value.code


def run_main_with_output(command: str, capsys):
    """Run main() and return (exit_code, decision, reason)."""
    with patch("sys.stdin", StringIO(create_hook_input(command))):
        with pytest.raises(SystemExit) as exc_info:
            git_safety_guard.main()
    captured = capsys.readouterr()
    response = json.loads(captured.out)
    hook_output = response["hookSpecificOutput"]
    return (
        exc_info.value.code,
        hook_output.get("permissionDecision"),
        hook_output.get("permissionDecisionReason", ""),
    )


class TestCloudSafePatterns:
    """Read-only cloud commands must be SAFE and never blocked."""

    @pytest.mark.parametrize(
        "command",
        [
            # AWS
            "aws s3 ls s3://bucket",
            "aws ec2 describe-instances",
            "aws sts get-caller-identity",
            "aws dynamodb list-tables",
            "aws rds describe-db-instances",
            "aws configure list",
            # gcloud / gsutil
            "gcloud compute instances list",
            "gcloud projects describe my-proj",
            "gcloud config list",
            "gcloud auth list",
            "gsutil ls gs://bucket",
            "gsutil stat gs://bucket/obj",
            # kubectl
            "kubectl get pods",
            "kubectl get pods -A",
            "kubectl describe deployment my-app",
            "kubectl logs -f pod-x",
            "kubectl top nodes",
            "kubectl config view",
            "kubectl delete pod x --dry-run=client",
        ],
    )
    def test_safe_cloud_commands(self, command):
        normalized = git_safety_guard.normalize_command(command)
        assert git_safety_guard.is_safe_pattern(normalized) is True, (
            f"'{command}' should be SAFE"
        )
        blocked, reason = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is False, f"'{command}' must not be blocked ({reason})"

    def test_dry_run_wins_over_blocked_at_runtime(self, capsys):
        """SAFE is evaluated before BLOCKED in main(), so a --dry-run preview
        of an otherwise-blocked command is allowed (it changes nothing)."""
        exit_code, decision, _reason = run_main_with_output(
            "kubectl delete pods --all --dry-run=server", capsys
        )
        assert exit_code == 0
        assert decision == "allow"


class TestAwsBlockedPatterns:
    """Catastrophic AWS operations must be BLOCKED with no escape hatch."""

    @pytest.mark.parametrize(
        "command,expected_reason",
        [
            ("aws s3 rb s3://prod --force", "deletes the bucket"),
            ("aws s3 rm s3://bucket --recursive", "recursive S3 object deletion"),
            ("aws s3 sync . s3://bucket --delete", "removes destination objects"),
            ("aws s3api delete-bucket --bucket prod", "deletes S3 bucket"),
            ("aws ec2 terminate-instances --instance-ids i-1", "terminates EC2"),
            ("aws ec2 delete-volume --volume-id vol-1", "EBS volume"),
            (
                "aws rds delete-db-instance --db-instance-identifier prod --skip-final-snapshot",
                "deletes RDS database",
            ),
            ("aws dynamodb delete-table --table-name users", "DynamoDB table"),
            ("aws cloudformation delete-stack --stack-name s", "CloudFormation stack"),
            ("aws eks delete-cluster --name prod", "container cluster"),
            ("aws iam delete-user --user-name bob", "IAM entity"),
            ("aws iam delete-role --role-name admin", "IAM entity"),
            ("aws kms schedule-key-deletion --key-id k", "KMS key"),
            (
                "aws secretsmanager delete-secret --secret-id s --force-delete-without-recovery",
                "NO recovery window",
            ),
            ("aws sqs purge-queue --queue-url q", "purges ALL messages"),
            ("aws route53 delete-hosted-zone --id Z1", "DNS hosted zone"),
            ("aws ecr delete-repository --repository-name r --force", "ECR repository"),
            ("aws backup delete-recovery-point --backup-vault-name v", "destroys backups"),
            ("aws organizations close-account --account-id 1", "organization-level"),
        ],
    )
    def test_aws_blocked(self, command, expected_reason):
        normalized = git_safety_guard.normalize_command(command)
        blocked, reason = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is True, f"'{command}' should be BLOCKED"
        assert expected_reason.lower() in reason.lower()


class TestGcloudBlockedPatterns:
    """Catastrophic gcloud/gsutil operations must be BLOCKED."""

    @pytest.mark.parametrize(
        "command,expected_reason",
        [
            ("gcloud projects delete my-proj --quiet", "ENTIRE GCP project"),
            ("gcloud compute instances delete vm-1 --zone us-east1-b", "compute instance"),
            ("gcloud compute disks delete data-disk", "disk/snapshot/image"),
            ("gcloud sql instances delete prod-db --quiet", "Cloud SQL instance"),
            ("gcloud container clusters delete prod", "GKE cluster"),
            ("gcloud storage rm -r gs://bucket", "recursive GCS deletion"),
            # generic fs `rm --recursive` pattern matches first - deny either way
            ("gcloud storage rm --recursive gs://bucket", "recursive"),
            ("gcloud storage buckets delete gs://bucket", "deletes GCS bucket"),
            ("gsutil rm -r gs://bucket/dir", "recursive gsutil deletion"),
            ("gsutil -m rm -r gs://bucket/dir", "recursive gsutil deletion"),
            ("gsutil rb gs://bucket", "removes GCS bucket"),
            ("gcloud kms keys versions destroy 1 --key k --keyring r --location l", "KMS key version"),
            ("gcloud iam service-accounts delete sa@p.iam.gserviceaccount.com", "service account"),
            ("gcloud dns managed-zones delete prod-zone", "DNS managed zone"),
            ("gcloud alpha firestore databases delete --database db", "Firestore database"),
            # Escalator: --quiet turns ANY delete into BLOCKED
            ("gcloud pubsub topics delete t --quiet", "--quiet"),
            ("gcloud functions delete f --quiet", "--quiet"),
        ],
    )
    def test_gcloud_blocked(self, command, expected_reason):
        normalized = git_safety_guard.normalize_command(command)
        blocked, reason = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is True, f"'{command}' should be BLOCKED"
        assert expected_reason.lower() in reason.lower()


class TestKubectlBlockedPatterns:
    """High blast-radius kubectl operations must be BLOCKED."""

    @pytest.mark.parametrize(
        "command,expected_reason",
        [
            ("kubectl delete namespace prod", "entire namespace"),
            ("kubectl delete ns prod", "entire namespace"),
            ("kubectl delete pods --all", "ALL resources"),
            ("kubectl delete deploy --all-namespaces", "all namespaces"),
            ("kubectl delete pods -A", "all namespaces"),
            ("kubectl delete pvc data-0", "persistent volume"),
            ("kubectl delete pv shared-disk", "persistent volume"),
            ("kubectl delete crd foo.example.com", "CRD cascades"),
            ("kubectl delete pod x --grace-period=0 --force", "grace-period 0"),
            ("kubectl replace --force -f deploy.yaml", "forced deletion/replacement"),
            ("kubectl -n prod delete namespace staging", "entire namespace"),
        ],
    )
    def test_kubectl_blocked(self, command, expected_reason):
        normalized = git_safety_guard.normalize_command(command)
        blocked, reason = git_safety_guard.check_blocked_pattern(normalized)
        assert blocked is True, f"'{command}' should be BLOCKED"
        assert expected_reason.lower() in reason.lower()


class TestCloudAskPatterns:
    """Recoverable-destructive cloud commands require ASK confirmation."""

    @pytest.mark.parametrize(
        "command",
        [
            "aws s3 rm s3://bucket/key.txt",
            "aws s3 rb s3://empty-bucket",
            "aws lambda delete-function --function-name f",
            "aws sqs delete-queue --queue-url q",
            "aws logs delete-log-group --log-group-name g",
            "aws ecs delete-service --service s --cluster c",
            "gcloud functions delete f",
            "gcloud run services delete svc",
            "gcloud pubsub topics delete t",
            "gsutil rm gs://bucket/obj.txt",
            "kubectl delete pod crashed-pod",
            "kubectl delete deployment my-app",
            "kubectl delete configmap stale-config",
            "kubectl drain node-1",
            "kubectl delete -f deploy.yaml",
        ],
    )
    def test_needs_confirmation(self, command):
        normalized = git_safety_guard.normalize_command(command)
        needs_confirm, reason = git_safety_guard.check_confirmation_pattern(normalized)
        assert needs_confirm is True, f"'{command}' should need confirmation"
        assert reason, "confirmation must carry a reason"

    @pytest.mark.parametrize(
        "command",
        [
            "kubectl delete pod crashed-pod",
            "aws lambda delete-function --function-name f",
            "gcloud functions delete f",
        ],
    )
    def test_main_emits_ask_with_exit_0(self, command, capsys):
        """Ask decisions MUST exit 0 - JSON is only processed on exit 0."""
        exit_code, decision, reason = run_main_with_output(command, capsys)
        assert exit_code == 0
        assert decision == "ask"
        assert "git-safety-guard" in reason

    def test_ask_decision_is_ask_not_deny(self):
        """check_confirmation_pattern_ex returns 'ask' for cloud groups."""
        normalized = git_safety_guard.normalize_command("kubectl delete pod x")
        needs, _reason, decision = git_safety_guard.check_confirmation_pattern_ex(normalized)
        assert needs is True
        assert decision == "ask"

    def test_git_confirmation_decision_stays_deny(self):
        """Legacy git force-push keeps the deny decision."""
        normalized = git_safety_guard.normalize_command("git push --force origin main")
        needs, _reason, decision = git_safety_guard.check_confirmation_pattern_ex(normalized)
        assert needs is True
        assert decision == "deny"


class TestCloudBypassPrevention:
    """Chaining, substitution and wrappers must not bypass the guard."""

    @pytest.mark.parametrize(
        "command",
        [
            "aws s3 ls && aws s3 rb --force s3://x",
            "kubectl get pods; kubectl delete ns prod",
            "gcloud info || gcloud projects delete p --quiet",
            "echo $(gcloud projects delete p --quiet)",
            "echo `aws ec2 terminate-instances --instance-ids i-1`",
            'bash -c "aws s3 rb --force s3://x"',
            'sh -c "kubectl delete namespace prod"',
            "sudo aws ec2 terminate-instances --instance-ids i-1",
            "AWS_PROFILE=prod aws rds delete-db-instance --db-instance-identifier d",
            "xargs kubectl delete ns",
            "AWS   S3   RB --FORCE S3://X",  # case + whitespace
            'aws s3 rb "--force" s3://x',  # quoted flag
        ],
    )
    def test_bypass_attempts_denied(self, command, capsys):
        exit_code, decision, _reason = run_main_with_output(command, capsys)
        assert exit_code == 1, f"'{command}' should be denied"
        assert decision == "deny"


class TestCloudFalsePositives:
    """Commands merely MENTIONING cloud CLIs must be allowed."""

    @pytest.mark.parametrize(
        "command",
        [
            'echo "aws s3 rb --force s3://x"',  # anchored: echo is the command
            "grep 'gcloud projects delete' runbook.md",
            "cat docs/aws-delete-runbook.md",
            "./aws-delete-helper.sh",
            "python deploy.py --skip-aws-delete",
            'git commit -m "add aws s3 rm cleanup script"',
            "terraform plan",
        ],
    )
    def test_false_positives_allowed(self, command, capsys):
        exit_code, decision, _reason = run_main_with_output(command, capsys)
        assert exit_code == 0, f"'{command}' is a false positive - must be allowed"
        assert decision == "allow"


class TestCloudEscapeHatches:
    """Env vars pre-approve the ASK tier only - never the BLOCKED tier."""

    def test_aws_env_allows_aws_ask(self, monkeypatch, capsys):
        monkeypatch.setenv("AWS_DESTRUCTIVE_CONFIRMED", "1")
        exit_code, decision, _ = run_main_with_output(
            "aws lambda delete-function --function-name f", capsys
        )
        assert exit_code == 0
        assert decision == "allow"

    def test_cloud_env_allows_kubectl_ask(self, monkeypatch, capsys):
        monkeypatch.setenv("CLOUD_DESTRUCTIVE_CONFIRMED", "1")
        exit_code, decision, _ = run_main_with_output("kubectl delete pod x", capsys)
        assert exit_code == 0
        assert decision == "allow"

    def test_aws_env_does_not_allow_gcloud(self, monkeypatch, capsys):
        monkeypatch.setenv("AWS_DESTRUCTIVE_CONFIRMED", "1")
        exit_code, decision, _ = run_main_with_output("gcloud functions delete f", capsys)
        assert exit_code == 0
        assert decision == "ask"

    def test_cloud_env_does_not_allow_git_force_push(self, monkeypatch, capsys):
        monkeypatch.setenv("CLOUD_DESTRUCTIVE_CONFIRMED", "1")
        exit_code, decision, _ = run_main_with_output(
            "git push --force origin main", capsys
        )
        assert exit_code == 1
        assert decision == "deny"

    @pytest.mark.parametrize(
        "env_var,command",
        [
            # Regression for the a5faf094 bug: NO env var bypasses BLOCKED
            ("GIT_FORCE_PUSH_CONFIRMED", "git reset --hard"),
            ("GIT_FORCE_PUSH_CONFIRMED", "rm -rf /home/user/data"),
            ("CLOUD_DESTRUCTIVE_CONFIRMED", "aws ec2 terminate-instances --instance-ids i-1"),
            ("AWS_DESTRUCTIVE_CONFIRMED", "aws s3 rb s3://prod --force"),
            ("GCLOUD_DESTRUCTIVE_CONFIRMED", "gcloud projects delete p --quiet"),
            ("KUBECTL_DESTRUCTIVE_CONFIRMED", "kubectl delete namespace prod"),
        ],
    )
    def test_no_env_var_bypasses_blocked_tier(self, monkeypatch, env_var, command, capsys):
        monkeypatch.setenv(env_var, "1")
        exit_code, decision, _ = run_main_with_output(command, capsys)
        assert exit_code == 1, f"BLOCKED must not be bypassable: '{command}'"
        assert decision == "deny"

    def test_git_force_push_env_still_works(self, monkeypatch):
        """Legacy escape hatch: force push allowed with GIT_FORCE_PUSH_CONFIRMED."""
        monkeypatch.setenv("GIT_FORCE_PUSH_CONFIRMED", "1")
        exit_code = run_main("git push --force origin main")
        assert exit_code == 0
