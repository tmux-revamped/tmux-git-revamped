#!/usr/bin/env bash
#
# render.sh: format a git segment with a configurable color and icon. Each kind,
# such as changed or ahead, reads @git_revamped_<kind>_color and
# @git_revamped_<kind>_icon, falling back to a sensible default.

[[ -n "${_GIT_REVAMPED_RENDER_LOADED:-}" ]] && return 0
_GIT_REVAMPED_RENDER_LOADED=1

_GIT_RENDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${_GIT_RENDER_DIR}/../tmux/tmux-ops.sh"

_git_reset() {
  get_tmux_option "@git_revamped_reset" "#[default]"
}

_git_option_exists() {
  [[ -n "$(tmux show-option -gq "${1}" 2>/dev/null)" ]]
}

_git_ci_label() {
  local option="@git_revamped_ci_${1}_label"
  if _git_option_exists "${option}"; then
    tmux show-option -gqv "${option}" 2>/dev/null
  else
    echo "${1}"
  fi
}

_git_default_color() {
  case "${1}" in
    changed)    echo "#[fg=yellow]" ;;
    insertions) echo "#[fg=green]" ;;
    deletions)  echo "#[fg=red]" ;;
    untracked)  echo "#[fg=blue]" ;;
    staged)     echo "#[fg=green]" ;;
    conflict)   echo "#[fg=red]" ;;
    state)      echo "#[fg=yellow]" ;;
    stash)      echo "#[fg=magenta]" ;;
    ahead)      echo "#[fg=green]" ;;
    behind)     echo "#[fg=yellow]" ;;
    commit)     echo "#[fg=blue]" ;;
    pr)         echo "#[fg=cyan]" ;;
    review)     echo "#[fg=magenta]" ;;
    issue)      echo "#[fg=blue]" ;;
    bug)        echo "#[fg=red]" ;;
    upstream)   echo "#[fg=cyan]" ;;
    noupstream) echo "#[fg=yellow]" ;;
    divergence) echo "#[fg=magenta]" ;;
    worktree)   echo "#[fg=cyan]" ;;
    submodule)  echo "#[fg=yellow]" ;;
    clean)      echo "#[fg=green]" ;;
    *)          echo "" ;;
  esac
}

_git_nerd_icon() {
  case "${1}" in
    changed) printf '\xef\x91\x99' ;;
    insertions) printf '\xef\x91\x97' ;;
    deletions) printf '\xef\x91\x98' ;;
    untracked) printf '\xf3\xb1\x80\xb6' ;;
    staged) printf '\xf3\xb0\x84\xad' ;;
    conflict) printf '\xef\x90\xa1' ;;
    state) printf '\xef\x90\x99' ;;
    stash) printf '\xf3\xb0\x80\xbc' ;;
    ahead) printf '\xf3\xb0\x81\x9d' ;;
    behind) printf '\xf3\xb0\x81\x85' ;;
    commit) printf '\xef\x91\xa4' ;;
    pr) printf '\xef\x90\x87' ;;
    review) printf '\xef\x91\x81' ;;
    issue) printf '\xef\x90\x9b' ;;
    bug) printf '\xef\x86\x88' ;;
    upstream) printf '\xef\x91\xbf' ;;
    noupstream) printf '\xf3\xb0\x85\xa4' ;;
    divergence) printf '\xf3\xb0\x93\x81' ;;
    worktree) printf '\xf3\xb0\x89\x95' ;;
    submodule) printf '\xef\x90\x94' ;;
    clean) printf '\xf3\xb0\x84\xac' ;;
    ci_pass) printf '\xf3\xb0\x97\xa0' ;;
    ci_fail) printf '\xf3\xb0\x85\x99' ;;
    ci_pending) printf '\xf3\xb0\x85\x90' ;;
    *) printf '' ;;
  esac
}

_git_icon_set() {
  get_tmux_option "@git_revamped_icons" "ascii"
}

_git_default_icon() {
  if [[ "$(_git_icon_set)" == "nerd" ]]; then
    _git_nerd_icon "${1}"
    return 0
  fi
  case "${1}" in
    changed)    echo "~" ;;
    insertions) echo "+" ;;
    deletions)  echo "-" ;;
    untracked)  echo "?" ;;
    staged)     echo "S" ;;
    conflict)   echo "!" ;;
    state)      echo "" ;;
    stash)      echo "$" ;;
    ahead)      echo "^" ;;
    behind)     echo "v" ;;
    commit)     echo "@" ;;
    pr)         echo "PR" ;;
    review)     echo "R" ;;
    issue)      echo "I" ;;
    bug)        echo "B" ;;
    upstream)   echo "->" ;;
    noupstream) echo "!" ;;
    divergence) echo "~>" ;;
    worktree)   echo "wt" ;;
    submodule)  echo "sub" ;;
    clean)      echo "ok" ;;
    *)          echo "" ;;
  esac
}

# git_render_count KIND VALUE -> "<color><icon> <value><reset>", icon optional.
git_render_count() {
  local kind="${1}" val="${2}" color icon
  color=$(get_tmux_option "@git_revamped_${kind}_color" "$(_git_default_color "${kind}")")
  icon=$(get_tmux_option "@git_revamped_${kind}_icon" "$(_git_default_icon "${kind}")")
  if [[ -n "${icon}" ]]; then
    echo "${color}${icon} ${val}$(_git_reset)"
  else
    echo "${color}${val}$(_git_reset)"
  fi
}

# git_render_branch BRANCH -> "<color><icon> <branch><reset>", icon optional.
git_render_branch() {
  local color icon
  color=$(get_tmux_option "@git_revamped_branch_color" "")
  icon=$(get_tmux_option "@git_revamped_branch_icon" "")
  if [[ -n "${icon}" ]]; then
    echo "${color}${icon} ${1}$(_git_reset)"
  else
    echo "${color}${1}$(_git_reset)"
  fi
}

_git_default_ci_icon() {
  if [[ "$(_git_icon_set)" == "nerd" ]]; then
    _git_nerd_icon "ci_${1}"
  else
    printf 'CI'
  fi
}

git_render_flag() {
  local kind="${1}" label="${2}" color icon
  color=$(get_tmux_option "@git_revamped_${kind}_color" "$(_git_default_color "${kind}")")
  icon=$(get_tmux_option "@git_revamped_${kind}_icon" "$(_git_default_icon "${kind}")")
  echo "${color}${icon:-${label}}$(_git_reset)"
}

# git_render_ci STATUS -> a CI token colored by status, empty for unknown status.
# pass is green, fail is red, pending is yellow; each color, icon, and label is
# overridable through @git_revamped_ci_<status>_{color,icon,label}.
git_render_ci() {
  local status="${1}" color icon label
  case "${status}" in
    pass)    color=$(get_tmux_option "@git_revamped_ci_pass_color" "#[fg=green]") ;;
    fail)    color=$(get_tmux_option "@git_revamped_ci_fail_color" "#[fg=red]") ;;
    pending) color=$(get_tmux_option "@git_revamped_ci_pending_color" "#[fg=yellow]") ;;
    *)       return 0 ;;
  esac
  icon=$(get_tmux_option "@git_revamped_ci_${status}_icon" "$(_git_default_ci_icon "${status}")")
  label="$(_git_ci_label "${status}")"
  if [[ -z "${label}" ]]; then
    echo "${color}${icon}$(_git_reset)"
  else
    echo "${color}${icon} ${label}$(_git_reset)"
  fi
}

export -f _git_reset
export -f _git_option_exists
export -f _git_ci_label
export -f _git_default_color
export -f _git_default_icon
export -f _git_nerd_icon
export -f _git_icon_set
export -f _git_default_ci_icon
export -f git_render_flag
export -f git_render_count
export -f git_render_branch
export -f git_render_ci
