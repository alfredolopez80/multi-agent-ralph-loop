#!/usr/bin/env bash
# plan-state-freshness.sh — Shared constants for plan-state freshness.
#
# Sourceable from any hook that needs to ask "how stale is too stale for
# this plan?". The constant lives here, not in plan-state-adaptive.sh, so
# session-start-restore-context.sh can import the same number without
# duplicating it (T110-f2 review item: no-duplicate-constants rule).
#
# Originally defined in plan-state-adaptive.sh:58. The plan-state-adaptive
# import replaces the local definition; the resume hook (which never
# imported adaptive) now reads from this lib.

# Plans older than this many minutes are considered stale. The writer
# side (session-end-handoff, plan-state-adaptive) and the reader side
# (session-start-restore) MUST agree on this threshold; both import it
# from here.
PLAN_STALENESS_MINUTES=30  # T110-f2: single source of truth
