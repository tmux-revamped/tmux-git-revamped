#!/usr/bin/env bash

[[ -n "${_GIT_REVAMPED_GIT_LOADED:-}" ]] && return 0
_GIT_REVAMPED_GIT_LOADED=1

GIT_PROVIDER_LIST_LIMIT=1000
GIT_PROVIDER_PAGE_SIZE=100
GIT_PROVIDER_MAX_PAGES=10

parse_branch() {
  local header="${1}" branch
  [[ "${header}" == "## "* ]] || return 1
  header="${header#"## "}"
  case "${header}" in
    "No commits yet on "*) header="${header#"No commits yet on "}" ;;
    "Initial commit on "*) header="${header#"Initial commit on "}" ;;
  esac
  branch="${header%%"..."*}"
  branch="${branch%%" "*}"
  [[ -n "${branch}" ]] && echo "${branch}"
}

parse_upstream() {
  [[ "${1}" =~ ^##\ (No\ commits\ yet\ on\ |Initial\ commit\ on\ )?[^[:space:]]+\.\.\.([^[:space:]]+) ]] && echo "${BASH_REMATCH[2]}"
}

parse_ahead() {
  [[ "${1}" =~ \[ahead\ ([0-9]+) ]] && { echo "${BASH_REMATCH[1]}"; return 0; }
  echo 0
}

parse_behind() {
  [[ "${1}" =~ behind\ ([0-9]+) ]] && { echo "${BASH_REMATCH[1]}"; return 0; }
  echo 0
}

count_modified() {
  printf '%s\n' "${1}" | awk '/^##/ {next} /^\?\?/ {next} NF {c++} END {print c+0}'
}

count_untracked() {
  printf '%s\n' "${1}" | grep -c '^??'
}

count_staged() {
  printf '%s\n' "${1}" | awk '/^##/{next} /^\?\?/{next} {x=substr($0,1,1); y=substr($0,2,1); if (x=="U"||y=="U"||(x=="D"&&y=="D")||(x=="A"&&y=="A")) next; if (index("MADRC",x)>0) s++} END {print s+0}'
}

count_conflict() {
  printf '%s\n' "${1}" | awk '/^##/{next} /^\?\?/{next} {x=substr($0,1,1); y=substr($0,2,1); if (x=="U"||y=="U"||(x=="D"&&y=="D")||(x=="A"&&y=="A")) c++} END {print c+0}'
}

count_submodule_dirty() {
  printf '%s\n' "${1}" | awk '/^\+/ {c++} END {print c+0}'
}

_read_first_line() {
  [[ -f "${1}" ]] || { echo ""; return 0; }
  head -1 "${1}" 2>/dev/null | tr -d ' \n'
}

_rebase_progress() {
  local dir="${1}" cur tot
  cur="$(_read_first_line "${dir}/${2}")"
  tot="$(_read_first_line "${dir}/${3}")"
  [[ "${cur}" =~ ^[0-9]+$ && "${tot}" =~ ^[0-9]+$ ]] || { echo ""; return 0; }
  echo " ${cur}/${tot}"
}

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

is_linked_worktree() {
  case "${1}" in
    */worktrees/*) return 0 ;;
    *) return 1 ;;
  esac
}

detached_head_label() {
  local sha="${1}" tag="${2}"
  [[ -z "${sha}" ]] && { echo ""; return 0; }
  if [[ -n "${tag}" ]]; then
    echo "${sha} ${tag}"
  else
    echo "${sha}"
  fi
}

ci_status_from_buckets() {
  local txt="${1}"
  [[ -z "${txt//[[:space:]]/}" ]] && { echo ""; return 0; }
  printf '%s\n' "${txt}" | grep -q '^fail$' && { echo "fail"; return 0; }
  printf '%s\n' "${txt}" | grep -q '^pending$' && { echo "pending"; return 0; }
  echo "pass"
}

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

parse_diffstat() {
  printf '%s\n' "${1}" | awk -F'\t' '{ c++; if ($1 ~ /^[0-9]+$/) i+=$1; if ($2 ~ /^[0-9]+$/) d+=$2 } END { print c+0, i+0, d+0 }'
}

truncate_branch() {
  local branch="${1}" max="${2:-25}"
  [[ "${max}" =~ ^[0-9]+$ ]] || max=25
  if (( ${#branch} > max )); then
    echo "${branch:0:max}..."
  else
    echo "${branch}"
  fi
}

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

host_from_url() {
  local url="${1}"
  url="${url#*://}"
  url="${url#*@}"
  url="${url%%[:/]*}"
  printf '%s' "${url}"
}

git_provider() {
  local url="${1}" provider
  provider="$(provider_from_url "${url}")"
  [[ -n "${provider}" ]] || provider="$(provider_from_url "$(_ssh_hostname "$(host_from_url "${url}")")")"
  printf '%s' "${provider}"
}

owner_from_url() {
  local url="${1}"
  url="${url#*://}"
  url="${url#*@}"
  url="${url#*[:/]}"
  printf '%s' "${url%%/*}"
}

gh_login_from_email() {
  local email="${1}" suffix="@users.noreply.github.com"
  [[ "${email}" == *"${suffix}" ]] || return 0
  email="${email%"${suffix}"}"
  printf '%s' "${email#*+}"
}

git_account_for_owner() {
  local owner="${1}" map="${2}" pair
  [[ -n "${owner}" ]] || return 0
  for pair in ${map}; do
    [[ "${pair%%=*}" == "${owner}" ]] || continue
    printf '%s' "${pair#*=}"
    return 0
  done
  return 0
}

provider_from_url() {
  case "${1}" in
    *github.com*) echo "github" ;;
    *gitlab.com*) echo "gitlab" ;;
    *) echo "" ;;
  esac
}

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
_gh_pr_count() { gh pr list --limit "${GIT_PROVIDER_LIST_LIMIT}" --json number --jq 'length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_review_count() { gh pr status --json reviewRequests --jq '.needsReview | length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_issue_count() { gh issue list --assignee @me --limit "${GIT_PROVIDER_LIST_LIMIT}" --json number --jq 'length' 2>/dev/null | head -1 | tr -d '\n '; }
_gh_bug_count() { gh issue list --assignee @me --limit "${GIT_PROVIDER_LIST_LIMIT}" --json labels --jq '[.[] | select(any(.labels[].name; . == "bug"))] | length' 2>/dev/null | head -1 | tr -d '\n '; }
_git_user_email() { git -C "${1}" config user.email 2>/dev/null; }
_ssh_hostname() { [[ -n "${1}" ]] && ssh -G "${1}" 2>/dev/null | awk '$1 == "hostname" { print $2; exit }'; }
_gh_token_for() { gh auth token --user "${1}" 2>/dev/null; }
_gh_ci_buckets() { gh pr checks --json bucket --jq '.[].bucket' 2>/dev/null; }
_glab_paged_count() {
  local marker="${1}" total=0 page count
  shift
  for ((page = 1; page <= GIT_PROVIDER_MAX_PAGES; page++)); do
    count="$("$@" --per-page "${GIT_PROVIDER_PAGE_SIZE}" --page "${page}" 2>/dev/null | grep -c "^${marker}")"
    [[ "${count}" =~ ^[0-9]+$ ]] || count=0
    total=$((total + count))
    ((count < GIT_PROVIDER_PAGE_SIZE)) && break
  done
  echo "${total}"
}
_glab_mr_count() { _glab_paged_count '!' glab mr list; }
_glab_review_count() { _glab_paged_count '!' glab mr list --reviewer=@me; }
_glab_issue_count() { _glab_paged_count '#' glab issue list; }
_glab_ci_status() { glab ci status </dev/null 2>/dev/null; }

is_git_repo() { _git_in_repo "${1}"; }

export -f host_from_url
export -f git_provider
export -f _ssh_hostname
export -f owner_from_url
export -f gh_login_from_email
export -f _git_user_email
export -f git_account_for_owner
export -f _gh_token_for
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
export -f _glab_paged_count
export -f _glab_mr_count
export -f _glab_review_count
export -f _glab_issue_count
export -f _glab_ci_status
export -f is_git_repo
