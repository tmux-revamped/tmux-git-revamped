#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/tmux_helpers.bash"

setup() {
  setup_tmux_server
  tmux set-option -g status-right '#{git}'
  tmux set-option -g status-left '#{git_branch}'
}

teardown() {
  teardown_tmux_server
}

status_job() {
  local option="${1}" job
  job="$(tmux show-option -gv "${option}")"
  job="${job#\#(}"
  printf '%s' "${job%)}"
}

make_repo() {
  local dir="${1}"
  mkdir -p "${dir}"
  git -C "${dir}" init -q -b trunk
  git -C "${dir}" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
}

@test "entrypoint - the status job quotes the pane path" {
  bash "${PLUGIN_DIR}/git-revamped.tmux"

  run tmux show-option -gv status-right

  [[ "${output}" == *"status '#{pane_current_path}')"* ]]
}

@test "entrypoint - the branch job quotes the pane path" {
  bash "${PLUGIN_DIR}/git-revamped.tmux"

  run tmux show-option -gv status-left

  [[ "${output}" == *"branch '#{pane_current_path}')"* ]]
}

@test "entrypoint - a repository whose path holds a space renders its branch" {
  local repo="${BATS_TEST_TMPDIR}/with space/repo"
  make_repo "${repo}"
  bash "${PLUGIN_DIR}/git-revamped.tmux"
  local job
  job="$(status_job status-left)"

  run sh -c "${job//\#\{pane_current_path\}/${repo}}"

  [[ "${output}" == *"trunk"* ]]
}
