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

_GIT_RESET="#[default]"

_git_default_color() {
  case "${1}" in
    changed)    echo "#[fg=yellow]" ;;
    insertions) echo "#[fg=green]" ;;
    deletions)  echo "#[fg=red]" ;;
    untracked)  echo "#[fg=blue]" ;;
    stash)      echo "#[fg=magenta]" ;;
    ahead)      echo "#[fg=green]" ;;
    behind)     echo "#[fg=yellow]" ;;
    commit)     echo "#[fg=blue]" ;;
    pr)         echo "#[fg=cyan]" ;;
    review)     echo "#[fg=magenta]" ;;
    issue)      echo "#[fg=blue]" ;;
    bug)        echo "#[fg=red]" ;;
    *)          echo "" ;;
  esac
}

_git_default_icon() {
  case "${1}" in
    changed)    echo "~" ;;
    insertions) echo "+" ;;
    deletions)  echo "-" ;;
    untracked)  echo "?" ;;
    stash)      echo "$" ;;
    ahead)      echo "^" ;;
    behind)     echo "v" ;;
    commit)     echo "@" ;;
    pr)         echo "PR" ;;
    review)     echo "R" ;;
    issue)      echo "I" ;;
    bug)        echo "B" ;;
    *)          echo "" ;;
  esac
}

# git_render_count KIND VALUE -> "<color><icon> <value><reset>", icon optional.
git_render_count() {
  local kind="${1}" val="${2}" color icon
  color=$(get_tmux_option "@git_revamped_${kind}_color" "$(_git_default_color "${kind}")")
  icon=$(get_tmux_option "@git_revamped_${kind}_icon" "$(_git_default_icon "${kind}")")
  if [[ -n "${icon}" ]]; then
    echo "${color}${icon} ${val}${_GIT_RESET}"
  else
    echo "${color}${val}${_GIT_RESET}"
  fi
}

# git_render_branch BRANCH -> "<color><icon> <branch><reset>", icon optional.
git_render_branch() {
  local color icon
  color=$(get_tmux_option "@git_revamped_branch_color" "")
  icon=$(get_tmux_option "@git_revamped_branch_icon" "")
  if [[ -n "${icon}" ]]; then
    echo "${color}${icon} ${1}${_GIT_RESET}"
  else
    echo "${color}${1}${_GIT_RESET}"
  fi
}

export -f _git_default_color
export -f _git_default_icon
export -f git_render_count
export -f git_render_branch
