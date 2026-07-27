#!/usr/bin/env bash

set -euo pipefail

reserved_label="$(printf '\143\157\144\145\170')"
failure_count=0

lowercase() {
  LC_ALL=C tr '[:upper:]' '[:lower:]'
}

report_failure() {
  printf 'Project hygiene error: %s\n' "$1" >&2
  failure_count=$((failure_count + 1))
}

check_text_value() {
  local label="$1"
  local value="$2"
  local normalized

  normalized="$(printf '%s' "$value" | lowercase)"
  if [[ "$normalized" == *"$reserved_label"* ]]; then
    report_failure "$label contains the reserved automation label."
  fi
}

branch_name="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"
if [[ -z "$branch_name" ]]; then
  branch_name="$(git branch --show-current 2>/dev/null || true)"
fi

if [[ -n "$branch_name" ]]; then
  check_text_value "Branch name" "$branch_name"

  case "$branch_name" in
    main|HEAD|[0-9]*/merge)
      ;;
    *)
      if ! printf '%s\n' "$branch_name" |
        LC_ALL=C grep -Eq '^(spike|feature|fix|refactor|test|docs|chore|release)/[a-z0-9]+(-[a-z0-9]+)*$'; then
        report_failure "Branch name must use an allowed type and a lowercase kebab-case summary."
      fi
      ;;
  esac
fi

while IFS= read -r -d '' file_path; do
  relative_path="${file_path#./}"
  check_text_value "Path '$relative_path'" "$relative_path"

  if LC_ALL=C grep -Iiq "$reserved_label" "$file_path"; then
    report_failure "File '$relative_path' contains the reserved automation label."
  fi
done < <(
  find . \
    \( -path './.git' -o -path './.build' -o -path './build' -o -path './DerivedData' \) -prune \
    -o -type f -print0
)

commit_subject="$(git log -1 --pretty=%s 2>/dev/null || true)"
check_text_value "Latest commit subject" "$commit_subject"
check_text_value "Change title" "${CHANGE_TITLE:-}"
check_text_value "Change body" "${CHANGE_BODY:-}"

if [[ "$failure_count" -ne 0 ]]; then
  printf 'Project hygiene failed with %d error(s).\n' "$failure_count" >&2
  exit 1
fi

printf 'Project hygiene passed.\n'
