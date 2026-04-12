"""
test_harness_scenarios.py — 4 failure-mode scenarios for multi-agent harness.

H7.2: Subagent spawn failure → retry 3x → escalate
H7.3: Worktree creation failure → abort cascade
H7.4: Teammate timeout (TTL exceeded) → cleanup
H7.5: Two coders produce merge conflict → detection works
"""

import pytest

from tests.harness.mock_model import (
    Event,
    EventType,
    EventSequence,
    MockModel,
)


# ============================================================
# H7.2: Subagent spawn failure → retry 3x → escalate
# ============================================================


class TestSpawnFailureRetry:
    """Scenario: subagent spawn fails, retries with exponential backoff,
    escalates to user after max retries exhausted."""

    def test_spawn_failure_sequence_length(self):
        """3 retries produces exactly 7 events (1 request + 3 failures + 2 retries + 1 escalate)."""
        events = EventSequence.spawn_failure(max_retries=3)
        model = MockModel(events)
        assert model.total == 7

    def test_spawn_failure_retries_with_backoff(self):
        """Each retry uses exponential backoff: 2s, 4s, 8s."""
        events = EventSequence.spawn_failure(max_retries=3)
        model = MockModel(events)

        retries = model.events_of_type(EventType.RETRY)
        assert len(retries) == 2  # 3 failures, but last one escalates (no retry after)

        assert retries[0].data["backoff_seconds"] == 2  # 2^1
        assert retries[1].data["backoff_seconds"] == 4  # 2^2

    def test_spawn_failure_escalates_after_max_retries(self):
        """After 3 failures, escalate (not retry infinitely)."""
        events = EventSequence.spawn_failure(max_retries=3)
        model = MockModel(events)

        assert model.has_event(EventType.ESCALATE)
        escalate = model.first(EventType.ESCALATE)
        assert escalate.data["max_retries"] == 3
        assert "escalating" in escalate.detail

    def test_spawn_failure_count_matches_retries(self):
        """Exactly max_retries SPAWN_FAILURE events."""
        model = MockModel(EventSequence.spawn_failure(max_retries=3))
        assert model.count(EventType.SPAWN_FAILURE) == 3

    def test_spawn_failure_custom_error_type(self):
        """Error type is propagated to escalate event."""
        model = MockModel(EventSequence.spawn_failure(error_type="api_timeout"))
        escalate = model.first(EventType.ESCALATE)
        assert escalate.data["final_error"] == "api_timeout"

    def test_spawn_success_after_retry(self):
        """Spawn succeeds after N failures (happy path recovery)."""
        model = MockModel(EventSequence.spawn_success_after_retry(fail_count=2))
        assert model.has_event(EventType.SPAWN_SUCCESS)
        assert model.count(EventType.SPAWN_FAILURE) == 2
        assert model.has_event(EventType.ESCALATE) is False

    def test_spawn_failure_event_order(self):
        """Events appear in correct order: request, fail, retry, fail, retry, fail, escalate."""
        model = MockModel(EventSequence.spawn_failure(max_retries=3))
        types = [e.type for e in model.events()]
        assert types == [
            EventType.SPAWN_REQUEST,
            EventType.SPAWN_FAILURE, EventType.RETRY,
            EventType.SPAWN_FAILURE, EventType.RETRY,
            EventType.SPAWN_FAILURE,
            EventType.ESCALATE,
        ]

    def test_single_retry_scenario(self):
        """With max_retries=1, no retry events — immediate escalate."""
        model = MockModel(EventSequence.spawn_failure(max_retries=1))
        assert model.count(EventType.RETRY) == 0
        assert model.has_event(EventType.ESCALATE)


# ============================================================
# H7.3: Worktree creation failure → abort cascade
# ============================================================


class TestWorktreeFailure:
    """Scenario: worktree creation fails (disk full, git error)
    triggers abort cascade with cleanup."""

    def test_worktree_failure_sequence_length(self):
        """5 events: spawn, create, failure, abort, cleanup."""
        model = MockModel(EventSequence.worktree_failure())
        assert model.total == 5

    def test_worktree_failure_has_abort(self):
        """Abort event present after worktree failure."""
        model = MockModel(EventSequence.worktree_failure())
        assert model.has_event(EventType.ABORT)

    def test_worktree_failure_has_cleanup(self):
        """Cleanup event present after abort."""
        model = MockModel(EventSequence.worktree_failure())
        assert model.has_event(EventType.CLEANUP)

    def test_worktree_failure_disk_full(self):
        """Disk full error propagated correctly."""
        model = MockModel(EventSequence.worktree_failure(error="disk_full"))
        failure = model.first(EventType.WORKTREE_FAILURE)
        assert "disk_full" in failure.detail

    def test_worktree_failure_git_error(self):
        """Git error propagated correctly."""
        model = MockModel(EventSequence.worktree_failure(error="git_error"))
        failure = model.first(EventType.WORKTREE_FAILURE)
        assert "git_error" in failure.detail

    def test_worktree_failure_event_order(self):
        """Events in correct cascade order."""
        model = MockModel(EventSequence.worktree_failure())
        types = [e.type for e in model.events()]
        assert types == [
            EventType.SPAWN_SUCCESS,
            EventType.WORKTREE_CREATE,
            EventType.WORKTREE_FAILURE,
            EventType.ABORT,
            EventType.CLEANUP,
        ]

    def test_worktree_abort_reason_matches_failure(self):
        """Abort reason references the original failure."""
        model = MockModel(EventSequence.worktree_failure(error="permission_denied"))
        abort = model.first(EventType.ABORT)
        assert abort.data["reason"] == "permission_denied"

    def test_worktree_success_no_abort(self):
        """Successful worktree has no abort or cleanup."""
        model = MockModel(EventSequence.worktree_success())
        assert model.has_event(EventType.WORKTREE_SUCCESS)
        assert model.has_event(EventType.ABORT) is False
        assert model.has_event(EventType.CLEANUP) is False


# ============================================================
# H7.4: Teammate timeout (TTL exceeded) → cleanup
# ============================================================


class TestTeammateTimeout:
    """Scenario: teammate exceeds TTL (30 min), triggers timeout → abort → cleanup."""

    def test_timeout_has_heartbeats(self):
        """Heartbeats precede timeout (agent was alive but slow)."""
        model = MockModel(EventSequence.teammate_timeout(ttl_minutes=30))
        heartbeats = model.events_of_type(EventType.HEARTBEAT)
        assert len(heartbeats) == 6  # 30min / 5min = 6 heartbeats

    def test_timeout_event_present(self):
        """Timeout event fired when TTL exceeded."""
        model = MockModel(EventSequence.teammate_timeout())
        assert model.has_event(EventType.TIMEOUT)

    def test_timeout_detail_shows_ttl(self):
        """Timeout detail includes TTL duration."""
        model = MockModel(EventSequence.teammate_timeout(ttl_minutes=30))
        timeout = model.first(EventType.TIMEOUT)
        assert timeout.data["ttl_minutes"] == 30

    def test_timeout_triggers_abort(self):
        """Timeout triggers abort (not just warning)."""
        model = MockModel(EventSequence.teammate_timeout())
        assert model.has_event(EventType.ABORT)

    def test_timeout_triggers_cleanup(self):
        """Cleanup removes worktree and branch."""
        model = MockModel(EventSequence.teammate_timeout())
        cleanup = model.first(EventType.CLEANUP)
        assert cleanup.data.get("remove_branch") is True

    def test_timeout_event_order(self):
        """Events: spawn, heartbeats..., timeout, abort, cleanup."""
        model = MockModel(EventSequence.teammate_timeout(ttl_minutes=10))
        types = [e.type for e in model.events()]

        # spawn + 2 heartbeats (10/5) + timeout + abort + cleanup = 6
        assert types[0] == EventType.SPAWN_SUCCESS
        assert types[-3] == EventType.TIMEOUT
        assert types[-2] == EventType.ABORT
        assert types[-1] == EventType.CLEANUP

    def test_heartbeat_elapsed_increments(self):
        """Each heartbeat shows increasing elapsed time."""
        model = MockModel(EventSequence.teammate_timeout(ttl_minutes=15))
        heartbeats = model.events_of_type(EventType.HEARTBEAT)
        elapsed = [hb.data["elapsed_minutes"] for hb in heartbeats]
        assert elapsed == [5, 10, 15]


# ============================================================
# H7.5: Merge conflict detection
# ============================================================


class TestMergeConflict:
    """Scenario: two coders produce merge conflict → detection works."""

    def test_merge_conflict_has_two_agents(self):
        """Both agents spawn and commit."""
        model = MockModel(EventSequence.merge_conflict())
        spawn_events = model.events_of_type(EventType.SPAWN_SUCCESS)
        assert len(spawn_events) == 2

    def test_merge_conflict_detected(self):
        """MERGE_CONFLICT event present after merge attempt."""
        model = MockModel(EventSequence.merge_conflict())
        assert model.has_event(EventType.MERGE_CONFLICT)

    def test_merge_conflict_lists_files(self):
        """Conflicting files are listed in event data."""
        model = MockModel(EventSequence.merge_conflict(
            conflicting_file="src/auth/login.py"))
        conflict = model.first(EventType.MERGE_CONFLICT)
        assert "src/auth/login.py" in conflict.data["conflicting_files"]

    def test_merge_conflict_after_commits(self):
        """Merge attempt happens AFTER both agents commit."""
        model = MockModel(EventSequence.merge_conflict())
        commits = model.events_of_type(EventType.COMMIT)
        assert len(commits) == 2

        # Merge attempt index > last commit index
        types = [e.type for e in model.events()]
        last_commit_idx = max(i for i, t in enumerate(types) if t == EventType.COMMIT)
        merge_idx = types.index(EventType.MERGE_ATTEMPT)
        assert merge_idx > last_commit_idx

    def test_clean_merge_no_conflict(self):
        """Clean merge (different files) has no MERGE_CONFLICT."""
        model = MockModel(EventSequence.merge_clean())
        assert model.has_event(EventType.MERGE_CLEAN)
        assert model.has_event(EventType.MERGE_CONFLICT) is False

    def test_merge_conflict_source_branch(self):
        """Source branch identified in conflict data."""
        model = MockModel(EventSequence.merge_conflict(agent_b="ralph-coder-beta"))
        conflict = model.first(EventType.MERGE_CONFLICT)
        assert conflict.data["source_branch"] == "wt-ralph-coder-beta"

    def test_serialization_round_trip(self):
        """Event sequence survives JSON serialization round-trip."""
        original = EventSequence.merge_conflict()
        model = MockModel(original)
        json_str = model.to_json()

        restored = MockModel.from_json(json_str)
        assert restored.total == model.total
        assert restored.has_event(EventType.MERGE_CONFLICT)

        for i in range(model.total):
            assert model.event_at(i).type == restored.event_at(i).type
