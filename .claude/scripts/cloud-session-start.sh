#!/usr/bin/env bash
# SessionStart hook. In a cloud session, it installs any package that
# DESCRIPTION names and the cached environment lacks, plus the tools that
# .claude/scripts/run-gates.sh uses (covr, pkgdown, air). Then it reports the
# R version. The output goes into Claude's context. On a local machine it
# exits at once.
#
# The environment itself is built by .claude/scripts/cloud-env-setup.sh, which
# goes in the "Setup script" field of the cloud environment settings.
#
# The script always exits 0, so a failed install never stops the session.

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

if ! command -v Rscript > /dev/null 2>&1; then
  echo "R is not installed in this cloud environment."
  echo "Paste .claude/scripts/cloud-env-setup.sh into the environment's Setup script field."
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# The air formatter. It downloads from a GitHub release, which the GitHub
# proxy can refuse, so a failure here is reported below and not fatal.
if ! command -v air > /dev/null 2>&1; then
  if curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh 2> /dev/null | sh > /dev/null 2>&1; then
    for dir in "$HOME/.local/bin" "$HOME/.cargo/bin"; do
      if [ -x "$dir/air" ] && [ -w /usr/local/bin ]; then
        cp "$dir/air" /usr/local/bin/air
      fi
    done
  fi
fi

Rscript - <<'EOF' || true
fields <- read.dcf("DESCRIPTION", c("Imports", "Suggests"))
pkgs <- unlist(strsplit(fields[!is.na(fields)], ","))
pkgs <- trimws(sub("\\(.*", "", pkgs))
pkgs <- c(pkgs, "devtools", "roxygen2", "rcmdcheck", "covr", "pkgdown")
pkgs <- unique(setdiff(pkgs, c("", rownames(installed.packages(priority = "base")))))
installed <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
missing <- pkgs[!installed]

for (pkg in missing) {
  tryCatch(
    pak::pkg_install(pkg, upgrade = FALSE, ask = FALSE),
    error = function(e) NULL
  )
}

still_missing <- missing[!vapply(missing, requireNamespace, logical(1), quietly = TRUE)]
cat("Cloud session: R", as.character(getRversion()), "\n")
if (length(still_missing) > 0) {
  cat(
    "These packages are not installed:",
    paste(still_missing, collapse = ", "),
    "\nTests and gates that need them cannot run. Report this limit with the results.\n"
  )
} else {
  cat("All DESCRIPTION packages and the gate tools are installed.\n")
}
if (!nzchar(Sys.which("air"))) {
  cat("air is not installed, so `air format --check` cannot run here.\n")
}
EOF

exit 0
