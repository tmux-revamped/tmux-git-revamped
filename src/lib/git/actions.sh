#!/usr/bin/env bash
#
# actions.sh: interactive actions bound to keys, never run under the status
# render. Every tmux call routes through the single _tmux seam and every external
# tool call routes through its own seam, so tests exercise the logic without ever
# launching lazygit, opening a browser, or driving a real tmux. Each action
# feature-detects its tool and only acts when the pane is inside a repository.

[[ -n "${_GIT_REVAMPED_ACTIONS_LOADED:-}" ]] && return 0
_GIT_REVAMPED_ACTIONS_LOADED=1

_GIT_ACTIONS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_GIT_ACTIONS_DIR}/../utils/has-command.sh"
# shellcheck source=/dev/null
source "${_GIT_ACTIONS_DIR}/../utils/constants.sh"
# shellcheck source=/dev/null
source "${_GIT_ACTIONS_DIR}/git.sh"

# Path of the dispatcher used by menu entries to run subcommands. Overridable.
GIT_ACTION_CMD="${GIT_ACTION_CMD:-${_GIT_ACTIONS_DIR}/../../git.sh}"

# _tmux ARGS -> the single tmux seam every action routes through. Tests mock it.
_tmux() { tmux "$@"; }

# _tmux_version -> the running tmux version number, like 3.4.
_tmux_version() { _tmux -V 2>/dev/null | awk '{print $2}'; }

# tmux_has_popup VERSION -> 0 when VERSION supports display-popup, tmux 3.2+.
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

# Interactive-tool seams. Tests mock these so nothing launches.
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

# git_action_lazygit DIR -> open lazygit rooted at DIR. Uses a popup on tmux 3.2+
# and a new window otherwise. No-op when DIR is not a repo or lazygit is absent.
git_action_lazygit() {
  local dir="${1}"
  is_git_repo "${dir}" || return 0
  has_command lazygit || return 0
  if tmux_has_popup "$(_tmux_version)"; then
    _tmux display-popup -d "${dir}" -E -w 90% -h 90% "lazygit"
  else
    _tmux new-window -c "${dir}" "lazygit"
  fi
}

# git_action_menu DIR -> show a branch-checkout menu for DIR. Refuses when the
# tree is dirty so an in-flight change is never clobbered. No-op outside a repo.
git_action_menu() {
  local dir="${1}"
  is_git_repo "${dir}" || return 0
  has_command git || return 0
  if ! _git_is_clean "${dir}"; then
    _tmux display-message "git-revamped: working tree dirty, not switching branch"
    return 0
  fi
  local list
  list="$(_git_branch_list "${dir}")"
  [[ -z "${list}" ]] && return 0
  local args=() count=0 b
  while IFS= read -r b; do
    [[ -z "${b}" ]] && continue
    args[count]="${b}"
    args[count + 1]=""
    args[count + 2]="run-shell \"${GIT_ACTION_CMD} checkout '${dir}' '${b}'\""
    count=$(( count + 3 ))
  done <<EOF
${list}
EOF
  _tmux display-menu -T "git branches" "${args[@]}"
}

# git_action_checkout DIR BRANCH -> check out BRANCH in DIR through the seam.
git_action_checkout() {
  local dir="${1}" branch="${2}"
  is_git_repo "${dir}" || return 0
  [[ -z "${branch}" ]] && return 0
  _git_checkout "${dir}" "${branch}"
}

# git_action_browse DIR -> open the current repo on its provider in a browser via
# the provider CLI. No-op when the provider or its CLI is unavailable.
git_action_browse() {
  local dir="${1}" url provider
  is_git_repo "${dir}" || return 0
  url="$(_git_remote_url "${dir}")"
  provider="$(provider_from_url "${url}")"
  if [[ "${provider}" == "github" ]] && has_command gh; then
    _gh_browse "${dir}"
  elif [[ "${provider}" == "gitlab" ]] && has_command glab; then
    _glab_browse "${dir}"
  fi
}

_doctor_tool() {
  if has_command "${1}"; then
    echo "tool ${1}: found"
  else
    echo "tool ${1}: missing"
  fi
}

# git_doctor DIR -> a plain-text capability report explaining what was detected.
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
  _doctor_tool jq
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
export -f git_action_menu
export -f git_action_checkout
export -f git_action_browse
export -f _doctor_tool
export -f git_doctor
