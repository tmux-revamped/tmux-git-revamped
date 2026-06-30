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

# parse_upstream HEADER -> the upstream ref like origin/main, empty when none.
parse_upstream() {
  [[ "${1}" =~ ^##\ [^[:space:]]+\.\.\.([^[:space:]]+) ]] && echo "${BASH_REMATCH[1]}"
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

# count_staged TEXT -> files staged in the index (porcelain column 1 set), from
# porcelain body lines. Excludes untracked and unmerged entries.
count_staged() {
  printf '%s\n' "${1}" | awk '/^##/{next} /^\?\?/{next} {x=substr($0,1,1); y=substr($0,2,1); if (x=="U"||y=="U"||(x=="D"&&y=="D")||(x=="A"&&y=="A")) next; if (index("MADRC",x)>0) s++} END {print s+0}'
}

# count_conflict TEXT -> unmerged (conflicted) files, from porcelain body lines.
# Unmerged is any entry with a U in either column, or the DD/AA pairs.
count_conflict() {
  printf '%s\n' "${1}" | awk '/^##/{next} /^\?\?/{next} {x=substr($0,1,1); y=substr($0,2,1); if (x=="U"||y=="U"||(x=="D"&&y=="D")||(x=="A"&&y=="A")) c++} END {print c+0}'
}

# count_submodule_dirty TEXT -> submodules with uncommitted changes, from the
# `git submodule status` output where a leading + marks a dirty submodule.
count_submodule_dirty() {
  printf '%s\n' "${1}" | awk '/^\+/ {c++} END {print c+0}'
}

# _read_first_line FILE -> the first line with surrounding whitespace stripped,
# empty when the file is absent.
_read_first_line() {
  [[ -f "${1}" ]] || { echo ""; return 0; }
  head -1 "${1}" 2>/dev/null | tr -d ' \n'
}

# _rebase_progress DIR CURFILE TOTFILE -> " cur/tot" when both files hold
# integers, empty otherwise. Used to annotate an in-progress rebase or am.
_rebase_progress() {
  local dir="${1}" cur tot
  cur="$(_read_first_line "${dir}/${2}")"
  tot="$(_read_first_line "${dir}/${3}")"
  [[ "${cur}" =~ ^[0-9]+$ && "${tot}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  echo " ${cur}/${tot}"
}

# git_special_state GITDIR -> the in-progress operation: rebase, am, merge,
# cherry-pick, revert, or bisect; empty when the worktree is in a normal state.
# A rebase or am also reports its step as " X/Y" when the counters are readable.
git_special_state() {
  local d="${1}"
  if [[ -d "${d}/rebase-merge" ]]; then
    echo "rebase$(_rebase_progress "${d}/rebase-merge" msgnum end)"
    return 0
  fi
  if [[ -d "${d}/rebase-apply" ]]; then
    if [[ -f "${d}/rebase-apply/applying" ]]; then
      echo "am$(_rebase_progress "${d}/rebase-apply" next last)"
    else
      echo "rebase$(_rebase_progress "${d}/rebase-apply" next last)"
    fi
    return 0
  fi
  [[ -f "${d}/MERGE_HEAD" ]] && { echo "merge"; return 0; }
  [[ -f "${d}/CHERRY_PICK_HEAD" ]] && { echo "cherry-pick"; return 0; }
  [[ -f "${d}/REVERT_HEAD" ]] && { echo "revert"; return 0; }
  [[ -f "${d}/BISECT_LOG" ]] && { echo "bisect"; return 0; }
  echo ""
}

# is_linked_worktree GITDIR -> 0 when the absolute git dir is a linked worktree,
# whose path lives under the main repo's worktrees directory.
is_linked_worktree() {
  case "${1}" in
    */worktrees/*) return 0 ;;
    *) return 1 ;;
  esac
}

# detached_head_label SHA TAG -> "SHA TAG" when a tag is known, else SHA; empty
# when no SHA is available.
detached_head_label() {
  local sha="${1}" tag="${2}"
  [[ -z "${sha}" ]] && { echo ""; return 0; }
  if [[ -n "${tag}" ]]; then
    echo "${sha} ${tag}"
  else
    echo "${sha}"
  fi
}

# ci_status_from_buckets TEXT -> fail, pending, pass, or empty from the bucket
# lines emitted by `gh pr checks --json bucket`.
ci_status_from_buckets() {
  local txt="${1}"
  [[ -z "${txt//[[:space:]]/}" ]] && { echo ""; return 0; }
  printf '%s\n' "${txt}" | grep -q '^fail$' && { echo "fail"; return 0; }
  printf '%s\n' "${txt}" | grep -q '^pending$' && { echo "pending"; return 0; }
  echo "pass"
}

# ci_status_from_glab TEXT -> fail, pending, pass, or empty from a glab pipeline
# status string.
ci_status_from_glab() {
  local txt
  txt="$(printf '%s' "${1}" | tr 'A-Z' 'a-z')"
  [[ -z "${txt//[[:space:]]/}" ]] && { echo ""; return 0; }
  case "${txt}" in
    *failed*|*canceled*|*cancelled*) echo "fail" ;;
    *running*|*pending*|*created*|*preparing*) echo "pending" ;;
    *success*|*passed*) echo "pass" ;;
    *) echo "" ;;
  esac
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
_git_dir() { git -C "${1}" --no-optional-locks rev-parse --absolute-git-dir 2>/dev/null; }
_git_numstat() { git -C "${1}" --no-optional-locks diff --numstat 2>/dev/null; }
_git_stash_count() { git -C "${1}" --no-optional-locks stash list 2>/dev/null | wc -l | tr -d ' '; }
_git_last_commit_ts() { git -C "${1}" --no-optional-locks log -1 --format=%ct 2>/dev/null; }
_git_remote_url() { git -C "${1}" config remote.origin.url 2>/dev/null; }
_git_short_sha() { git -C "${1}" --no-optional-locks rev-parse --short HEAD 2>/dev/null; }
_git_describe() { git -C "${1}" --no-optional-locks describe --tags --abbrev=0 2>/dev/null; }
_git_base_count() { git -C "${1}" --no-optional-locks rev-list --count "${2}..HEAD" 2>/dev/null | head -1 | tr -d '\n '; }
_git_submodule_status() { git -C "${1}" --no-optional-locks submodule status 2>/dev/null; }
_git_now() { date +%s 2>/dev/null || echo 0; }
_gh_pr_count() { gh pr list --json number --jq 'length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_review_count() { gh pr status --json reviewRequests --jq '.needsReview | length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_issue_count() { gh issue list --assignee @me --json number --jq 'length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_bug_count() { gh issue list --assignee @me --json labels --jq '[.[] | select(any(.labels[].name; . == "bug"))] | length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_ci_buckets() { gh pr checks --json bucket --jq '.[].bucket' 2>/dev/null; }
_glab_mr_count() { glab mr list 2>/dev/null | grep -cE '^!'; }
# shellcheck disable=SC2120
_glab_review_count() { glab mr list --reviewer=@me 2>/dev/null | grep -cE '^!'; return 0; }
# shellcheck disable=SC2120
_glab_issue_count() { glab issue list 2>/dev/null | grep -cE '^#'; return 0; }
_glab_ci_status() { glab ci status </dev/null 2>/dev/null; }

# is_git_repo DIR -> 0 when DIR is inside a git work tree.
is_git_repo() { _git_in_repo "${1}"; }

export -f parse_branch
export -f parse_upstream
export -f parse_ahead
export -f parse_behind
export -f count_modified
export -f count_untracked
export -f count_staged
export -f count_conflict
export -f count_submodule_dirty
export -f _read_first_line
export -f _rebase_progress
export -f git_special_state
export -f is_linked_worktree
export -f detached_head_label
export -f ci_status_from_buckets
export -f ci_status_from_glab
export -f _git_dir
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
export -f _git_short_sha
export -f _git_describe
export -f _git_base_count
export -f _git_submodule_status
export -f _git_now
export -f _gh_pr_count
export -f _gh_review_count
export -f _gh_issue_count
export -f _gh_bug_count
export -f _gh_ci_buckets
export -f _glab_mr_count
export -f _glab_review_count
export -f _glab_issue_count
export -f _glab_ci_status
export -f is_git_repo
