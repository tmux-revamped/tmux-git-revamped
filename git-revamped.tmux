#!/usr/bin/env bash
#
# git-revamped.tmux: TPM entry point.
#
# Replaces the #{git} and #{git_branch} placeholders in status-left and
# status-right with calls to the dispatcher, scoped to the active pane's path.
# Optionally binds keys for the lazygit popup, the branch switcher menu, and the
# open-in-browser action when the matching @git_revamped_key_* option is set.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_CMD="${PLUGIN_DIR}/src/git.sh"

placeholders=(
  "\#{git}"
  "\#{git_branch}"
)

metrics=(status branch)

render_mode="$(tmux show-option -gqv "@git_revamped_render")"

target_for() {
  if [[ "${render_mode}" == "options" ]]; then
    printf '#{E:@git_revamped_out_%s}' "${1}"
  else
    printf "#(%s %s '#{pane_current_path}')" "${GIT_CMD}" "${1}"
  fi
}

interpolate() {
  local value="${1}"
  local i
  for (( i = 0; i < ${#placeholders[@]}; i++ )); do
    value="${value//${placeholders[i]}/$(target_for "${metrics[i]}")}"
  done
  echo "${value}"
}

used_metrics() {
  local text="${1}" used="" i
  for (( i = 0; i < ${#placeholders[@]}; i++ )); do
    if [[ "${text}" == *${placeholders[i]}* || "${text}" == *"@git_revamped_out_${metrics[i]}}"* ]]; then
      used="${used:+${used} }${metrics[i]}"
    fi
  done
  echo "${used}"
}

update_option() {
  local option="${1}"
  local current
  current=$(tmux show-option -gqv "${option}")
  tmux set-option -gq "${option}" "$(interpolate "${current}")"
}

# bind_action_key OPTION SUBCOMMAND -> bind the key held in OPTION to run the
# dispatcher SUBCOMMAND against the active pane's path. Unset option means no
# binding, so the plugin never clobbers a key the user did not opt into.
bind_action_key() {
  local option="${1}" subcommand="${2}" fallback="${3:-}" key
  key=$(tmux show-option -gqv "${option}")
  if ! tmux show-options -g 2>/dev/null | grep -qE "^${option}( |$)"; then
    key="${fallback}"
  fi
  [[ -z "${key}" ]] && return 0
  tmux bind-key "${key}" run-shell "${GIT_CMD} ${subcommand} '#{pane_current_path}'"
}

chmod +x "${GIT_CMD}" 2>/dev/null || true

status_text="$(tmux show-option -gqv status-left) $(tmux show-option -gqv status-right)"
tmux set-option -gq "@git_revamped_published" "$(used_metrics "${status_text}")"

update_option "status-left"
update_option "status-right"

if [[ "${render_mode}" == "options" ]]; then
  "${GIT_CMD}" start 2>/dev/null || true
fi

bind_action_key "@git_revamped_key_lazygit" "lazygit"
bind_action_key "@git_revamped_key_menu" "menu" "M-v"
bind_action_key "@git_revamped_key_browse" "browse"
