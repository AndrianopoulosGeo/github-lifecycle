#!/usr/bin/env bash
# ADR bash smoke tests — exercises bash snippets embedded in /init-project,
# /feature, /develop, /quick-fix, /hotfix, /decision, /compress-decisions
# against fixture decisions folders.
#
# Run: bash evals/adr-bash-smoke-test.sh
# Exits 0 on all-pass, 1 on any failure.

set -u

PASS=0
FAIL=0
FAILURES=()

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS  $label"
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("$label: expected [$expected], got [$actual]")
    echo "  FAIL  $label"
    echo "        expected: [$expected]"
    echo "        actual:   [$actual]"
  fi
}

new_fixture() {
  local d
  d=$(mktemp -d -t adr-smoke-XXXXXX)
  mkdir -p "$d/docs/decisions"
  echo "$d"
}

mk_template() {
  local fixture="$1"
  cat > "$fixture/docs/decisions/0000-template.md" <<'EOF'
---
title: NNNN — <title>
status: accepted
---
# Template
EOF
}

mk_adr() {
  local fixture="$1" id="$2" slug="$3" status="$4" date="$5"
  cat > "$fixture/docs/decisions/${id}-${slug}.md" <<EOF
---
title: ADR-${id}
status: ${status}
date: ${date}
---
## Decision
We do thing.
EOF
}

# ===========================================================================
# Test 1: next-ADR-number — empty dir (only template)
# ===========================================================================
echo "Test group 1: next-ADR-number computation"
F=$(new_fixture); mk_template "$F"
LAST=$(ls "$F/docs/decisions/" 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-template' | sort | tail -1 | cut -d'-' -f1)
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
assert_eq "empty (only template) -> NEXT=0001" "0001" "$NEXT"
rm -rf "$F"

# Test 2: next-ADR-number — one accepted ADR
F=$(new_fixture); mk_template "$F"; mk_adr "$F" "0001" "first" "accepted" "2026-01-01"
LAST=$(ls "$F/docs/decisions/" 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-template' | sort | tail -1 | cut -d'-' -f1)
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
assert_eq "one ADR (0001) -> NEXT=0002" "0002" "$NEXT"
rm -rf "$F"

# Test 3: next-ADR-number — non-monotonic (0007 max)
F=$(new_fixture); mk_template "$F"
mk_adr "$F" "0001" "a" "accepted" "2026-01-01"
mk_adr "$F" "0003" "b" "superseded" "2026-02-01"
mk_adr "$F" "0007" "c" "accepted" "2026-03-01"
LAST=$(ls "$F/docs/decisions/" 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-template' | sort | tail -1 | cut -d'-' -f1)
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
assert_eq "0001/0003/0007 -> NEXT=0008" "0008" "$NEXT"
rm -rf "$F"

# Test 4: octal safety — 0008 is correctly handled
F=$(new_fixture); mk_template "$F"
mk_adr "$F" "0008" "octal-trap" "accepted" "2026-01-01"
LAST=$(ls "$F/docs/decisions/" 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-template' | sort | tail -1 | cut -d'-' -f1)
NEXT=$(printf "%04d" $((10#${LAST:-0} + 1)))
assert_eq "octal 0008 -> NEXT=0009 (no octal interpretation error)" "0009" "$NEXT"
rm -rf "$F"

# ===========================================================================
# Test group 2: ADR_COUNT (file-count style — used by /develop Phase 10.x.1)
# ===========================================================================
echo "Test group 2: ADR_COUNT file-count"

# Test 5: empty dir
F=$(new_fixture); mk_template "$F"
ADR_COUNT=$(ls "$F/docs/decisions/" 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-' | wc -l | tr -d ' ')
ADR_COUNT=${ADR_COUNT:-0}
assert_eq "empty -> count=0" "0" "$ADR_COUNT"
rm -rf "$F"

# Test 6: 5 ADRs
F=$(new_fixture); mk_template "$F"
for i in 1 2 3 4 5; do mk_adr "$F" "000$i" "x$i" "accepted" "2026-01-01"; done
ADR_COUNT=$(ls "$F/docs/decisions/" 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-' | wc -l | tr -d ' ')
ADR_COUNT=${ADR_COUNT:-0}
assert_eq "5 ADRs -> count=5" "5" "$ADR_COUNT"
rm -rf "$F"

# Test 7: missing dir produces 0
F=$(mktemp -d -t adr-smoke-XXXXXX)  # no decisions folder
ADR_COUNT=$(ls "$F/docs/decisions/" 2>/dev/null | grep -E '^[0-9]{4}-' | grep -v '^0000-' | wc -l | tr -d ' ')
ADR_COUNT=${ADR_COUNT:-0}
assert_eq "missing dir -> count=0 (no two-line bug)" "0" "$ADR_COUNT"
rm -rf "$F"

# ===========================================================================
# Test group 3: status breakdown (used by /wiki status decisions count)
# ===========================================================================
echo "Test group 3: ADR status breakdown"

# Test 8: mix of statuses
F=$(new_fixture); mk_template "$F"
mk_adr "$F" "0001" "a" "accepted" "2026-01-01"
mk_adr "$F" "0002" "b" "accepted" "2026-01-01"
mk_adr "$F" "0003" "c" "superseded" "2026-01-01"
mk_adr "$F" "0004" "d" "deprecated" "2026-01-01"
ACCEPTED=0; SUPERSEDED=0; DEPRECATED=0
for f in "$F/docs/decisions/"[0-9][0-9][0-9][0-9]-*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "0000-template.md" ] && continue
  STATUS=$(grep -E '^status:' "$f" 2>/dev/null | head -1 | awk '{print $2}')
  case "$STATUS" in
    accepted) ACCEPTED=$((ACCEPTED + 1)) ;;
    superseded) SUPERSEDED=$((SUPERSEDED + 1)) ;;
    deprecated) DEPRECATED=$((DEPRECATED + 1)) ;;
  esac
done
assert_eq "mix: 2 accepted" "2" "$ACCEPTED"
assert_eq "mix: 1 superseded" "1" "$SUPERSEDED"
assert_eq "mix: 1 deprecated" "1" "$DEPRECATED"
rm -rf "$F"

# Test 9: template skipped (single accepted ADR + template)
F=$(new_fixture); mk_template "$F"
mk_adr "$F" "0001" "lonely" "accepted" "2026-01-01"
ACCEPTED=0
for f in "$F/docs/decisions/"[0-9][0-9][0-9][0-9]-*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "0000-template.md" ] && continue
  STATUS=$(grep -E '^status:' "$f" 2>/dev/null | head -1 | awk '{print $2}')
  [ "$STATUS" = "accepted" ] && ACCEPTED=$((ACCEPTED + 1))
done
assert_eq "template excluded from accepted count" "1" "$ACCEPTED"
rm -rf "$F"

# ===========================================================================
# Test group 4: precondition guards
# ===========================================================================
echo "Test group 4: precondition guards"

# Test 10: guard fails when folder missing
F=$(mktemp -d -t adr-smoke-XXXXXX)
GUARD_RC=0
(
  cd "$F"
  if [ ! -d docs/decisions ] || [ ! -f docs/decisions/0000-template.md ]; then
    exit 1
  fi
) || GUARD_RC=$?
assert_eq "missing folder -> guard exits 1" "1" "$GUARD_RC"
rm -rf "$F"

# Test 11: guard passes when folder + template present
F=$(new_fixture); mk_template "$F"
GUARD_RC=0
(
  cd "$F"
  if [ ! -d docs/decisions ] || [ ! -f docs/decisions/0000-template.md ]; then
    exit 1
  fi
) || GUARD_RC=$?
assert_eq "folder + template -> guard exits 0" "0" "$GUARD_RC"
rm -rf "$F"

# Test 12: cmp guard works when source template missing (init-project regression test)
F=$(new_fixture); mk_template "$F"
mk_adr "$F" "0001" "x" "accepted" "2026-01-01"
NEEDS_PROMPT=0
LOCAL="$F/docs/decisions/0001-x.md"
SOURCE="/nonexistent/path/templates/decisions/0001-x.md"
if [ -f "$LOCAL" ] && [ -f "$SOURCE" ] && ! cmp -s "$SOURCE" "$LOCAL"; then
  NEEDS_PROMPT=1
fi
assert_eq "missing source template -> NEEDS_PROMPT=0 (no spurious prompt)" "0" "$NEEDS_PROMPT"
rm -rf "$F"

# ===========================================================================
# Test group 5: portable date parsing (compress-decisions --archive-superseded)
# ===========================================================================
echo "Test group 5: portable date parsing"

# Test 13: probe-and-detect produces a working to_epoch
if date -d "2020-01-01" +%s >/dev/null 2>&1; then
  to_epoch() { date -d "$1" +%s 2>/dev/null; }
else
  to_epoch() { date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null; }
fi
EPOCH=$(to_epoch "2020-01-01")
# 2020-01-01 UTC = 1577836800; allow some timezone slack (within 1 day)
EXPECTED_BASE=1577836800
DIFF=$(( (EPOCH - EXPECTED_BASE) > 0 ? (EPOCH - EXPECTED_BASE) : (EXPECTED_BASE - EPOCH) ))
if [ "$DIFF" -lt 86400 ]; then
  PASS=$((PASS + 1)); echo "  PASS  to_epoch produces 2020-01-01 epoch within 1d"
else
  FAIL=$((FAIL + 1))
  FAILURES+=("to_epoch: 2020-01-01 produced $EPOCH, expected near $EXPECTED_BASE")
  echo "  FAIL  to_epoch: 2020-01-01 produced $EPOCH, expected near $EXPECTED_BASE"
fi

# Test 14: to_epoch returns empty (and grep stays silent) on bad input
BAD=$(to_epoch "not-a-date" 2>/dev/null || true)
assert_eq "to_epoch on bad input -> empty (skipped, not crash)" "" "$BAD"

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "============================================="
echo "Smoke tests:  $PASS passed,  $FAIL failed"
echo "============================================="
if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  - $f"
  done
  exit 1
fi
exit 0
