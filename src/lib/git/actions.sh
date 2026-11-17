#!/usr/bin/env bash

[[ -n "${_GIT_REVAMPED_ACTIONS_LOADED:-}" ]] && return 0
_GIT_REVAMPED_ACTIONS_LOADED=1

_GIT_ACTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_GIT_ACTIONS_DIR}/../utils/has-command.sh"
# shellcheck source=/dev/null
source "${_GIT_ACTIONS_DIR}/../utils/constants.sh"
# shellcheck source=/dev/null
source "${_GIT_ACTIONS_DIR}/git.sh"

GIT_ACTION_CMD="${GIT_ACTION_CMD:-${_GIT_ACTIONS_DIR}/../../git.sh}"

_tmux() { tmux "$@"; }

_tmux_version() { _tmux -V 2>/dev/null | awk '{print $2}'; }

tmux_has_popup() {
  local v="${1}" major minor
  v="${v//[!0-9.]/}"
  [[ -n "${v}" ]] || return 1
  major="${v%%.*}"
  minor="${v#*.}"
  minor="${minor%%.*}"
  [[ "${major}" =~ ^[0-9]+$ ]] || return 1
  [[ "${minor}" =~ ^[0-9]+$ ]] || minor=0
  (( major > 3 )) && return 0
  (( major == 3 && minor >= 2 )) && return 0
  return 1
}

_git_is_clean() { [[ -z "$(git -C "${1}" --no-optional-locks status --porcelain 2>/dev/null)" ]]; }
_git_branch_list() { git -C "${1}" --no-optional-locks for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null; }
_git_checkout() { git -C "${1}" checkout "${2}" >/dev/null 2>&1; }
_gh_browse() {
  (
    cd "${1}" || exit 0
    gh browse
  ) >/dev/null 2>&1
}
_glab_browse() {
  (
    cd "${1}" || exit 0
    glab repo view --web
  ) >/dev/null 2>&1
}

_git_say() { _tmux display-message "git-revamped: ${1}"; }

_git_outside() { _git_say "this pane is not in a git repository"; }

git_action_lazygit() {
  local dir="${1}" start
  if ! is_git_repo "${dir}"; then
    _git_outside
    return 0
  fi
  if ! has_command lazygit; then
    _git_say "lazygit is not installed"
    return 0
  fi
  start="$(_git_menu_label "${dir}")"
  if tmux_has_popup "$(_tmux_version)"; then
    _tmux display-popup -d "${start}" -E -w 90% -h 90% "lazygit"
  else
    _tmux new-window -c "${start}" "lazygit"
  fi
}

_git_menu_label() {
  local text="${1}" out="" char i
  for ((i = 0; i < ${#text}; i++)); do
    char="${text:i:1}"
    [[ "${char}" == "#" ]] && char="##"
    out="${out}${char}"
  done
  printf '%s' "${out}"
}

_git_menu_command() {
  local shell out="" char i
  shell="$(printf '%q checkout %q %q' "${GIT_ACTION_CMD}" "${1}" "${2}")"
  for ((i = 0; i < ${#shell}; i++)); do
    char="${shell:i:1}"
    case "${char}" in
      "#") char="####" ;;
      "\\" | '"' | '$') char="\\${char}" ;;
    esac
    out="${out}${char}"
  done
  printf 'run-shell "%s"' "${out}"
}

git_action_menu() {
  local dir="${1}"
  if ! is_git_repo "${dir}"; then
    _git_outside
    return 0
  fi
  has_command git || return 0
  if ! _git_is_clean "${dir}"; then
    _tmux display-message "git-revamped: working tree dirty, not switching branch"
    return 0
  fi
  local list
  list="$(_git_branch_list "${dir}")"
  if [[ -z "${list}" ]]; then
    _git_say "no branch to switch to yet"
    return 0
  fi
  local args=() count=0 b
  while IFS= read -r b; do
    [[ -z "${b}" ]] && continue
    args[count]="$(_git_menu_label "${b}")"
    args[count + 1]=""
    args[count + 2]="$(_git_menu_command "${dir}" "${b}")"
    count=$(( count + 3 ))
  done <<EOF
${list}
EOF
  _tmux display-menu -T "git branches" "${args[@]}"
}

git_action_checkout() {
  local dir="${1}" branch="${2}"
  is_git_repo "${dir}" || return 0
  [[ -z "${branch}" ]] && return 0
  _git_checkout "${dir}" "${branch}"
}

git_action_browse() {
  local dir="${1}" url provider tool
  if ! is_git_repo "${dir}"; then
    _git_outside
    return 0
  fi
  url="$(_git_remote_url "${dir}")"
  provider="$(provider_from_url "${url}")"
  case "${provider}" in
    github) tool="gh" ;;
    gitlab) tool="glab" ;;
    *)
      _git_say "no GitHub or GitLab remote to open"
      return 0
      ;;
  esac
  if ! has_command "${tool}"; then
    _git_say "${tool} is not installed"
    return 0
  fi
  if [[ "${tool}" == "gh" ]]; then
    _gh_browse "${dir}" && return 0
  else
    _glab_browse "${dir}" && return 0
  fi
  _git_say "${tool} could not open the repository page"
}

_doctor_tool() {
  if has_command "${1}"; then
    echo "tool ${1}: found"
  else
    echo "tool ${1}: missing"
  fi
}

git_doctor() {
  local dir="${1:-${PWD}}"
  echo "tmux-git-revamped doctor"
  echo "version: ${GIT_REVAMPED_VERSION:-unknown}"
  if is_git_repo "${dir}"; then
    echo "repo: yes ${dir}"
  else
    echo "repo: no ${dir}"
  fi
  _doctor_tool git
  _doctor_tool gh
  _doctor_tool glab
  _doctor_tool lazygit
  if is_git_repo "${dir}"; then
    local provider
    provider="$(provider_from_url "$(_git_remote_url "${dir}")")"
    if [[ -n "${provider}" ]]; then
      echo "provider: ${provider}"
    else
      echo "provider: none"
    fi
  fi
  if tmux_has_popup "$(_tmux_version)"; then
    echo "popup: yes"
  else
    echo "popup: no"
  fi
}

export -f _tmux
export -f _tmux_version
export -f tmux_has_popup
export -f _git_is_clean
export -f _git_branch_list
export -f _git_checkout
export -f _gh_browse
export -f _glab_browse
export -f git_action_lazygit
export -f _git_menu_label
export -f _git_menu_command
export -f git_action_menu
export -f git_action_checkout
export -f git_action_browse
export -f _doctor_tool
export -f git_doctor
