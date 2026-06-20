#!/usr/bin/env bash
#
# git-revamped.tmux: TPM entry point.
#
# Replaces the #{git} and #{git_branch} placeholders in status-left and
# status-right with calls to the dispatcher, scoped to the active pane's path.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_CMD="${PLUGIN_DIR}/src/git.sh"

placeholders=(
  "\#{git}"
  "\#{git_branch}"
)

commands=(
  "#(${GIT_CMD} status #{pane_current_path})"
  "#(${GIT_CMD} branch #{pane_current_path})"
)

interpolate() {
  local value="${1}"
  local i
  for (( i = 0; i < ${#placeholders[@]}; i++ )); do
    value="${value//${placeholders[i]}/${commands[i]}}"
  done
  echo "${value}"
}

update_option() {
  local option="${1}"
  local current
  current=$(tmux show-option -gqv "${option}")
  tmux set-option -gq "${option}" "$(interpolate "${current}")"
}

chmod +x "${GIT_CMD}" 2>/dev/null || true

update_option "status-left"
update_option "status-right"
