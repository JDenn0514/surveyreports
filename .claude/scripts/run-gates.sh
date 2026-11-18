#!/usr/bin/env bash
# Run all surveyreports validation gates in order, log full output per gate,
# and print one compact summary. Built for the tester agent: ONE background
# call, one summary read, zero polling turns.
#
# Usage:
#   bash .claude/scripts/run-gates.sh <log-dir> [--skip-pkgdown] [--baseline]
#
#   --skip-pkgdown  Skip gate 6. Allowed ONLY under the skip conditions in
#                   r-package-profile.md (never when NAMESPACE changes).
#   --baseline      Run only gate 2 (tests and coverage with the 95%
#                   floor). For the orchestrator's Before-column capture
#                   on a clean tree.
#
# Gates: 1 document(), 2 tests + covr in one run, 4 R CMD build,
# 5 R CMD check (no tests), 6 check_pkgdown(), 8 air format --check.
# Gate 3 (run_examples()) is removed: R CMD check runs the examples.
# Gate 7 (covr) is removed: gate 2 is now the covr run.
#
# Exit code 0 = all gates PASS. The summary names the log file of any FAIL.
# Gate definitions live in r-package-profile.md, Validation commands section.

set -u
LOGDIR="${1:?usage: run-gates.sh <log-dir> [--skip-pkgdown] [--baseline]}"
shift || true
SKIP_PKGDOWN=0
BASELINE=0
for a in "$@"; do
  case "$a" in
    --skip-pkgdown) SKIP_PKGDOWN=1 ;;
    --baseline)     BASELINE=1 ;;
  esac
done
mkdir -p "$LOGDIR"

SUMMARY=""
OVERALL=0

row() { SUMMARY="${SUMMARY}${1}\n"; }

fail_gate() { # name logfile note
  row "| $1 | FAIL | $3 — read $2 |"
  OVERALL=1
}

pass_gate() { # name note
  row "| $1 | PASS | $2 |"
}

# --- Gate 2: tests and coverage in one covr run -------------------------
# covr-report.R runs the whole test suite once under covr. One run gives
# the test counts, the package total and the per-file detail. A separate
# devtools::test() gate cost a second run of the suite for no new answer.
#
# NOT_CRAN=true matches CI. Without it testthat skips every
# expect_snapshot() and skip_on_cran() block, and coverage reads low.
#
# The gate fails when a test fails, when covr did not run, or when the
# package total is below 95%. It runs on every PR, also when no R/ file
# changed.
#
# The changed-file list feeds the per-file report only. The gates run
# before the shipper commits, so the list takes committed, uncommitted and
# untracked R/ files, measured from the merge base with develop. A deleted
# file has nothing to cover and drops out. The base is the newer of the
# merge bases with develop and origin/develop, so a stale local develop does
# not count develop's own commits as changes.
changed_r_files() {
  local base b2
  base=$(git merge-base develop HEAD 2>/dev/null)
  b2=$(git merge-base origin/develop HEAD 2>/dev/null)
  if [ -z "$base" ]; then
    base=${b2:-develop}
  elif [ -n "$b2" ] && git merge-base --is-ancestor "$base" "$b2"; then
    base=$b2
  fi
  {
    git diff --name-only "$base" -- 'R/*.R'
    git ls-files --others --exclude-standard -- 'R/*.R'
  } 2>/dev/null | sort -u | while read -r f; do
    [ -f "$f" ] && printf '%s,' "$f"
  done
}

gate_test_covr() {
  local name="tests + covr"
  local log="$LOGDIR/gate-2-test-covr.log"
  local changed
  changed=$(changed_r_files)
  NOT_CRAN=true CHANGED_R_FILES="$changed" \
    Rscript .claude/scripts/covr-report.R > "$log" 2>&1
  local covr_ver
  covr_ver=$(grep -oE '^COVR_VERSION=[0-9.]+' "$log" | tail -1 | cut -d= -f2)
  if grep -q '^COVR_TOO_OLD' "$log"; then
    local covr_min
    covr_min=$(grep -oE '^COVR_TOO_OLD minimum=[0-9.]+' "$log" | cut -d= -f2)
    fail_gate "$name" "$log" "covr ${covr_ver} is older than ${covr_min}; update covr with pak::pak('covr') (environment HOLD, not a code BLOCK)"
    return
  fi
  local summary nfail pct nunc
  summary=$(grep -E '^\[ FAIL [0-9]+' "$log" | tail -1)
  nfail=$(grep -oE '^TEST_FAILURES=[0-9]+' "$log" | tail -1 | cut -d= -f2)
  pct=$(grep -oE '^COVERAGE_PCT=[0-9.]+' "$log" | tail -1 | cut -d= -f2)
  nunc=$(grep -oE '^UNCOVERED_COUNT=[0-9]+' "$log" | tail -1 | cut -d= -f2)
  local detail="${summary}; coverage ${pct}% (covr ${covr_ver:-unknown})"
  if [ -n "$nunc" ]; then
    detail="${detail}; changed R/ files: $(grep -c '^CHANGED_FILE_PCT' "$log"), uncovered lines in them: ${nunc}"
  fi
  if [ -z "$pct" ]; then
    fail_gate "$name" "$log" "covr did not run"
  elif [ -z "$nfail" ]; then
    fail_gate "$name" "$log" "no test result line found"
  elif [ "$nfail" != "0" ]; then
    fail_gate "$name" "$log" "$summary"
  elif awk "BEGIN{exit !($pct >= 95)}"; then
    pass_gate "$name" "$detail"
  else
    fail_gate "$name" "$log" "coverage ${pct}% is below the 95% floor; ${summary}"
  fi
}

# --- Gate 8: air format --check ----------------------------------------
gate_air() {
  local log="$LOGDIR/gate-8-air.log"
  if ! command -v air > /dev/null 2>&1; then
    echo "air is not on PATH" > "$log"
    fail_gate "air format --check" "$log" "air is not installed"
    return
  fi
  if air format --check . > "$log" 2>&1; then
    pass_gate "air format --check" "every R file is formatted"
  else
    local n
    n=$(grep -c '^Would reformat:' "$log")
    fail_gate "air format --check" "$log" "${n} file(s) need 'air format .'"
  fi
}

if [ "$BASELINE" = "1" ]; then
  gate_test_covr
else
  # --- Gate 1: document() + drift check --------------------------------
  log="$LOGDIR/gate-1-document.log"
  Rscript -e 'devtools::document()' > "$log" 2>&1
  if git diff --quiet -- NAMESPACE man/ 2>>"$log"; then
    pass_gate "devtools::document()" "no NAMESPACE/man drift"
  else
    git diff --stat -- NAMESPACE man/ >> "$log" 2>&1
    fail_gate "devtools::document()" "$log" "NAMESPACE/man drift (builder forgot document())"
  fi

  gate_test_covr

  # --- Gate 3: removed -------------------------------------------------
  # Gate 3 ran devtools::run_examples(). R CMD check (gate 5) runs every
  # example too, so the gate was a second run of the same code. Gates 4, 5
  # and 6 keep their numbers and log names.

  # --- Gate 4: R CMD build ----------------------------------------------
  log="$LOGDIR/gate-4-build.log"
  rm -f ./*.tar.gz
  if R CMD build . > "$log" 2>&1 && ls ./*.tar.gz >/dev/null 2>&1; then
    TARBALL=$(ls -t ./*.tar.gz | head -1)
    pass_gate "R CMD build" "$TARBALL"
  else
    TARBALL=""
    fail_gate "R CMD build" "$log" "no tarball produced"
  fi

  # --- Gate 5: R CMD check --as-cran ------------------------------------
  log="$LOGDIR/gate-5-check.log"
  if [ -n "$TARBALL" ]; then
    # --no-manual mirrors CI (.github/workflows/R-CMD-check.yaml passes
    # build_args 'c("--no-manual","--compact-vignettes=gs+qpdf")'). Without it
    # the PDF-manual step needs a LaTeX toolchain; where none is installed it
    # raises 1 ERROR + 1 WARNING and leaves surveyreports-manual.tex behind as
    # a third NOTE — none of which CI ever sees, and none of which a builder
    # can fix.
    # --no-tests: gate 2 already ran the full test suite, and CI runs the
    # check with tests on five operating system and R version pairs. The
    # check still runs the examples, which replaces the old gate 3.
    R CMD check --as-cran --no-manual --no-tests "$TARBALL" > "$log" 2>&1
    CHECKDIR=$(ls -dt ./*.Rcheck 2>/dev/null | head -1)
    [ -n "$CHECKDIR" ] && cp "$CHECKDIR/00check.log" "$LOGDIR/gate-5-00check.log" 2>/dev/null
    status_line=$(grep -E '^Status:' "$log" | tail -1)
    if printf '%s' "$status_line" | grep -qE 'ERROR|WARNING'; then
      fail_gate "R CMD check --as-cran" "$LOGDIR/gate-5-00check.log" "$status_line"
    else
      pass_gate "R CMD check --as-cran" "${status_line:-Status line missing — verify log} (NOTEs need review per pre-approved list)"
    fi
    [ -n "$CHECKDIR" ] && rm -rf "$CHECKDIR"
    rm -f "$TARBALL"
  else
    fail_gate "R CMD check --as-cran" "$LOGDIR/gate-4-build.log" "skipped — build failed"
  fi

  # --- Gate 6: pkgdown ----------------------------------------------------
  if [ "$SKIP_PKGDOWN" = "1" ]; then
    row "| pkgdown::check_pkgdown() | SKIPPED | scope (log the skip reason in audit.md) |"
  else
    log="$LOGDIR/gate-6-pkgdown.log"
    # check_pkgdown() checks _pkgdown.yml without building the site: every
    # exported topic must be in the reference index. It takes seconds.
    # CI (.github/workflows/pkgdown.yaml) still builds the full site on
    # every PR.
    if Rscript -e 'pkgdown::check_pkgdown()' > "$log" 2>&1; then
      pass_gate "pkgdown::check_pkgdown()" "_pkgdown.yml is complete"
    else
      fail_gate "pkgdown::check_pkgdown()" "$log" "_pkgdown.yml check error"
    fi
  fi

  gate_air
fi

# tree-hash.sh hashes the working tree, uncommitted and untracked files
# included, changelog/ left out. commit-and-pr compares this value to skip
# its pre-flight when the code has not changed since the gates ran.
echo ""
echo "## Gate summary"
echo "| Gate | Result | Notes |"
echo "|---|---|---|"
printf "%b" "$SUMMARY"
echo ""
echo "Tree: $(bash .claude/scripts/tree-hash.sh)"
echo "Logs: $LOGDIR"
[ "$OVERALL" = "0" ] && echo "ALL GATES PASS" || echo "GATE FAILURE(S) — read only the named log(s)"
exit $OVERALL
