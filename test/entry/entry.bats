#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../helpers.bash"

ENTRY="${BATS_TEST_DIRNAME}/../../git-revamped.tmux"

setup() {
  setup_test_environment
  export SPAWN_LOG="${TEST_TMPDIR}/spawn.log"
  nohup() { printf '%s\n' "$*" >> "${SPAWN_LOG}"; }
  export -f nohup
}

teardown() {
  cleanup_test_environment
}

@test "entry - jobs mode passes the pane path to the dispatcher" {
  tmux set-option -gq "status-right" "[#{git}]"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file status-right)")" == "[#($(cd "${BATS_TEST_DIRNAME}/../.." && pwd)/src/git.sh status '#{pane_current_path}')]" ]]
}

@test "entry - options mode turns a placeholder into an option read" {
  tmux set-option -gq "@git_revamped_render" "options"
  tmux set-option -gq "status-right" "[#{git}][#{git_branch}]"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file status-right)")" == "[#{E:@git_revamped_out_status}][#{E:@git_revamped_out_branch}]" ]]
}

@test "entry - options mode starts the ticker" {
  tmux set-option -gq "@git_revamped_render" "options"
  tmux set-option -gq "status-right" "[#{git}]"

  bash "${ENTRY}"

  [[ "$(cat "${SPAWN_LOG}")" == *"/src/git.sh daemon" ]]
}

@test "entry - jobs mode starts no ticker" {
  tmux set-option -gq "status-right" "[#{git}]"

  bash "${ENTRY}"

  [ ! -f "${SPAWN_LOG}" ]
}

@test "entry - only metrics on the status line are published" {
  tmux set-option -gq "status-right" "#{git_branch}"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file @git_revamped_published)")" == "branch" ]]
}
