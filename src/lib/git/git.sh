#!/usr/bin/env bash
#
# git.sh: git repository status data.
#
# Pure parsers turn `git status -b --porcelain` and `git diff --numstat` text into
# counts. Every real git or provider call sits behind a seam the tests override,
# so no repository is touched under test.

[[ -n "${_GIT_REVAMPED_GIT_LOADED:-}" ]] && return 0
_GIT_REVAMPED_GIT_LOADED=1

# parse_branch HEADER -> branch name from a porcelain header line.
parse_branch() {
  [[ "${1}" =~ ^##\ ([^.[:space:]]+) ]] && echo "${BASH_REMATCH[1]}"
}

# parse_ahead HEADER -> commits ahead of upstream, 0 when none.
parse_ahead() {
  [[ "${1}" =~ \[ahead\ ([0-9]+) ]] && { echo "${BASH_REMATCH[1]}"; return 0; }
  echo 0
}

# parse_behind HEADER -> commits behind upstream, 0 when none.
parse_behind() {
  [[ "${1}" =~ behind\ ([0-9]+) ]] && { echo "${BASH_REMATCH[1]}"; return 0; }
  echo 0
}

# count_modified TEXT -> tracked files with changes, from porcelain body lines.
count_modified() {
  printf '%s\n' "${1}" | awk '/^##/ {next} /^\?\?/ {next} NF {c++} END {print c+0}'
}

# count_untracked TEXT -> untracked files, from porcelain body lines.
count_untracked() {
  printf '%s\n' "${1}" | grep -c '^??'
}

# parse_diffstat TEXT -> "<changed> <insertions> <deletions>" from numstat.
parse_diffstat() {
  printf '%s\n' "${1}" | awk -F'\t' '{ c++; if ($1 ~ /^[0-9]+$/) i+=$1; if ($2 ~ /^[0-9]+$/) d+=$2 } END { print c+0, i+0, d+0 }'
}

# truncate_branch BRANCH MAX -> BRANCH, shortened with an ellipsis past MAX.
truncate_branch() {
  local branch="${1}" max="${2:-25}"
  [[ "${max}" =~ ^[0-9]+$ ]] || max=25
  if (( ${#branch} > max )); then
    echo "${branch:0:max}..."
  else
    echo "${branch}"
  fi
}

# relative_time NOW TS -> a short age like 12m, 3h, 5d.
relative_time() {
  [[ "${1}" =~ ^[0-9]+$ && "${2}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  local diff=$(( ${1} - ${2} ))
  (( diff < 0 )) && diff=0
  if (( diff < 3600 )); then
    echo "$(( diff / 60 ))m"
  elif (( diff < 86400 )); then
    echo "$(( diff / 3600 ))h"
  else
    echo "$(( diff / 86400 ))d"
  fi
}

# provider_from_url URL -> github, gitlab, or empty.
provider_from_url() {
  case "${1}" in
    *github.com*) echo "github" ;;
    *gitlab.com*) echo "gitlab" ;;
    *) echo "" ;;
  esac
}

# Host-probe seams. Tests override these.
_git_in_repo() { git -C "${1}" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; }
_git_branch() { git -C "${1}" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null; }
_git_status() { git -C "${1}" --no-optional-locks status -b --porcelain 2>/dev/null; }
_git_numstat() { git -C "${1}" --no-optional-locks diff --numstat 2>/dev/null; }
_git_stash_count() { git -C "${1}" --no-optional-locks stash list 2>/dev/null | wc -l | tr -d ' '; }
_git_last_commit_ts() { git -C "${1}" --no-optional-locks log -1 --format=%ct 2>/dev/null; }
_git_remote_url() { git -C "${1}" config remote.origin.url 2>/dev/null; }
_git_now() { date +%s 2>/dev/null || echo 0; }
_gh_pr_count() { gh pr list --json number --jq 'length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_review_count() { gh pr status --json reviewRequests --jq '.needsReview | length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_issue_count() { gh issue list --assignee @me --json number --jq 'length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_bug_count() { gh issue list --assignee @me --json labels --jq '[.[] | select(any(.labels[].name; . == "bug"))] | length' 2>/dev/null | head -1 | tr -d '\n '; }
_glab_mr_count() { glab mr list 2>/dev/null | grep -cE '^!'; }
# shellcheck disable=SC2120
_glab_review_count() { glab mr list --reviewer=@me 2>/dev/null | grep -cE '^!'; return 0; }
# shellcheck disable=SC2120
_glab_issue_count() { glab issue list 2>/dev/null | grep -cE '^#'; return 0; }

# is_git_repo DIR -> 0 when DIR is inside a git work tree.
is_git_repo() { _git_in_repo "${1}"; }

export -f parse_branch
export -f parse_ahead
export -f parse_behind
export -f count_modified
export -f count_untracked
export -f parse_diffstat
export -f truncate_branch
export -f relative_time
export -f provider_from_url
export -f _git_in_repo
export -f _git_branch
export -f _git_status
export -f _git_numstat
export -f _git_stash_count
export -f _git_last_commit_ts
export -f _git_remote_url
export -f _git_now
export -f _gh_pr_count
export -f _gh_review_count
export -f _gh_issue_count
export -f _gh_bug_count
export -f _glab_mr_count
export -f _glab_review_count
export -f _glab_issue_count
export -f is_git_repo
