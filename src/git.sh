#!/usr/bin/env bash
#
# git.sh: command dispatcher for tmux-git-revamped.
#
# Usage: git.sh status <dir> | branch <dir> | refresh <dir>
#
# The full status string can run slow work (diff, stash, provider API calls), so
# it is cached per directory in a tmux server user-option and refreshed by a
# detached worker. The status render returns the cached value instantly. The
# branch alone is one fast rev-parse, so it is computed live.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export CACHE_PREFIX="git_revamped"
export PLUGIN_LOG_NS="git-revamped"

# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/has-command.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/tmux/tmux-ops.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/utils/cache.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/git/git.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/src/lib/git/render.sh"

git_max_age() {
  get_tmux_option "@git_revamped_interval" "5"
}

_git_key() {
  printf 'status_%s' "$(printf '%s' "${1}" | tr -c 'A-Za-z0-9' '_')"
}

# git_web_segment DIR -> provider PR, review, issue, and bug counts, leading
# space. On GitHub the issue count excludes bug-labeled issues, which surface as
# a separate bug segment. GitLab reports no separate bug count.
git_web_segment() {
  local dir="${1}" url provider pr review issue bug=0 total
  url="$(_git_remote_url "${dir}")"
  provider="$(provider_from_url "${url}")"
  [[ -z "${provider}" ]] && return 0
  if [[ "${provider}" == "github" ]] && has_command gh; then
    pr="$(_gh_pr_count)"; review="$(_gh_review_count)"
    total="$(_gh_issue_count)"; bug="$(_gh_bug_count)"
    [[ "${total}" =~ ^[0-9]+$ ]] || total=0
    [[ "${bug}" =~ ^[0-9]+$ ]] || bug=0
    issue=$(( total - bug ))
    (( issue < 0 )) && issue=0
  elif [[ "${provider}" == "gitlab" ]] && has_command glab; then
    pr="$(_glab_mr_count)"; review="$(_glab_review_count)"; issue="$(_glab_issue_count)"
  else
    return 0
  fi
  [[ "${pr}" =~ ^[0-9]+$ ]] || pr=0
  [[ "${review}" =~ ^[0-9]+$ ]] || review=0
  [[ "${issue}" =~ ^[0-9]+$ ]] || issue=0
  [[ "${bug}" =~ ^[0-9]+$ ]] || bug=0
  echo " $(git_render_count pr "${pr}") $(git_render_count review "${review}") $(git_render_count issue "${issue}") $(git_render_count bug "${bug}")"
}

# git_build_status DIR -> the full formatted status string.
git_build_status() {
  local dir="${1}" status header branch out modified untracked
  status="$(_git_status "${dir}")"
  [[ -z "${status}" ]] && return 0
  header="$(printf '%s\n' "${status}" | head -1)"
  branch="$(truncate_branch "$(parse_branch "${header}")" "$(get_tmux_option "@git_revamped_max_branch" "25")")"
  out="$(git_render_branch "${branch}")"

  modified="$(count_modified "${status}")"
  local changed=0 ins=0 del=0
  if (( modified > 0 )); then
    read -r changed ins del <<< "$(parse_diffstat "$(_git_numstat "${dir}")")"
  fi
  (( changed > 0 )) && out="${out} $(git_render_count changed "${changed}")"
  (( ins > 0 )) && out="${out} $(git_render_count insertions "${ins}")"
  (( del > 0 )) && out="${out} $(git_render_count deletions "${del}")"

  if [[ "$(get_tmux_option "@git_revamped_untracked" "1")" == "1" ]]; then
    untracked="$(count_untracked "${status}")"
    (( untracked > 0 )) && out="${out} $(git_render_count untracked "${untracked}")"
  fi

  if [[ "$(get_tmux_option "@git_revamped_staged" "0")" == "1" ]]; then
    local staged; staged="$(count_staged "${status}")"
    (( staged > 0 )) && out="${out} $(git_render_count staged "${staged}")"
  fi

  if [[ "$(get_tmux_option "@git_revamped_conflict" "1")" == "1" ]]; then
    local conflict; conflict="$(count_conflict "${status}")"
    (( conflict > 0 )) && out="${out} $(git_render_count conflict "${conflict}")"
  fi

  if [[ "$(get_tmux_option "@git_revamped_stash" "0")" == "1" ]]; then
    local stash; stash="$(_git_stash_count "${dir}")"
    [[ "${stash}" =~ ^[0-9]+$ ]] && (( stash > 0 )) && out="${out} $(git_render_count stash "${stash}")"
  fi

  if [[ "$(get_tmux_option "@git_revamped_ahead_behind" "0")" == "1" ]]; then
    local ahead behind
    ahead="$(parse_ahead "${header}")"; behind="$(parse_behind "${header}")"
    (( ahead > 0 )) && out="${out} $(git_render_count ahead "${ahead}")"
    (( behind > 0 )) && out="${out} $(git_render_count behind "${behind}")"
  fi

  if [[ "$(get_tmux_option "@git_revamped_state" "1")" == "1" ]]; then
    local state; state="$(git_special_state "$(_git_dir "${dir}")")"
    [[ -n "${state}" ]] && out="${out} $(git_render_count state "${state}")"
  fi

  if [[ "$(get_tmux_option "@git_revamped_last_commit" "0")" == "1" ]]; then
    local ts age; ts="$(_git_last_commit_ts "${dir}")"
    age="$(relative_time "$(_git_now)" "${ts}")"
    [[ -n "${age}" ]] && out="${out} $(git_render_count commit "${age}")"
  fi

  if [[ "$(get_tmux_option "@git_revamped_web" "0")" == "1" ]]; then
    out="${out}$(git_web_segment "${dir}")"
  fi

  echo "${out}"
}

git_refresh() {
  cache_set "${2}" "$(git_build_status "${1}")"
}

git_render_status() {
  local dir="${1:-${PWD}}" key
  is_git_repo "${dir}" || { echo ""; return 0; }
  key="$(_git_key "${dir}")"
  cache_render "${key}" "$(git_max_age)" git_refresh "${dir}" "${key}"
}

git_render_branch_cmd() {
  local dir="${1:-${PWD}}" branch
  is_git_repo "${dir}" || { echo ""; return 0; }
  branch="$(_git_branch "${dir}")"
  [[ -z "${branch}" ]] && return 0
  git_render_branch "$(truncate_branch "${branch}" "$(get_tmux_option "@git_revamped_max_branch" "25")")"
}

main() {
  local cmd="${1:-}" dir="${2:-}"

  if [[ "${cmd}" == "refresh" ]]; then
    is_git_repo "${dir}" && git_refresh "${dir}" "$(_git_key "${dir}")"
    return 0
  fi

  case "${cmd}" in
    status) git_render_status "${dir}" ;;
    branch) git_render_branch_cmd "${dir}" ;;
    *)      return 0 ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
