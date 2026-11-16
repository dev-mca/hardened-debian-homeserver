#!/bin/bash
# Pre-commit check: looks for secrets and private data in this repository.
# Usage: scripts/check-secrets.sh        (run from anywhere, it checks the repo root)
# 1. gitleaks (if installed)
# 2. grep for typical secret patterns and for private values that must be anonymized
# Exit code 1 if something is found.
cd "$(dirname "$0")/.." || exit 2
rc=0

if command -v gitleaks >/dev/null 2>&1; then
  echo "== gitleaks"
  gitleaks detect --no-git --source . --redact --no-banner || rc=1
else
  echo "== gitleaks not installed, skipped"
fi

echo "== grep: secret patterns"
if grep -rnIE --exclude-dir=.git --exclude=check-secrets.sh \
  -e '(password|passwd|secret|token|api[_-]?key)[A-Za-z_]*[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+_.-]{8,}' \
  -e 'BEGIN [A-Z ]*PRIVATE KEY' \
  -e 'tskey-[A-Za-z0-9-]+' \
  -e 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}' \
  -e 'hc-ping\.com/[0-9a-f-]{8,}' \
  -e 'ntfy\.sh/[A-Za-z0-9_-]{8,}' \
  -e '[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}' \
  . | grep -vE '\$\{[A-Z_]+\}|<[A-Z_]+>'; then rc=1; fi

echo "== grep: private values (must be anonymized)"
# Add your own real values to the local file .private-patterns (one regex per line, ignored by git).
pats=(-e '192\.168\.' -e '\.ts\.net' -e '@protonmail' -e '@gmail' -e '\.duckdns\.org')
[ -f .private-patterns ] && pats+=(-f .private-patterns)
if grep -rnIiE --exclude-dir=.git --exclude=check-secrets.sh --exclude=.private-patterns "${pats[@]}" . ; then rc=1; fi

[ $rc -eq 0 ] && echo "OK: nothing found" || echo "FOUND something, check the lines above"
exit $rc
