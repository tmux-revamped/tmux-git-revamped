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

@test "entry - a second run keeps metrics already turned into option reads" {
  tmux set-option -gq "@git_revamped_render" "options"
  tmux set-option -gq "status-right" "[#{E:@git_revamped_out_status}]"

  bash "${ENTRY}"

  [[ "$(cat "$(_mock_opt_file @git_revamped_published)")" == "status" ]]
}

@test "entry - jobs mode releases a ticker left running by options mode" {
  # Arrange
  tmux set-option -gq "@git_revamped_ticker_pid" "4242"
  tmux set-option -gq "status-right" "[#{git}]"

  # Act
  bash "${ENTRY}"

  # Assert
  [ ! -f "$(_mock_opt_file @git_revamped_ticker_pid)" ]
}

@test "entry - a plugin path with a space and a quote runs as one word" {
  # Arrange
  local root="${TEST_TMPDIR}/it's a plugin"
  mkdir -p "${root}/src"
  cp "${ENTRY}" "${root}/git-revamped.tmux"
  printf '#!/bin/sh\nprintf "ran %%s" "$1"\n' > "${root}/src/git.sh"
  chmod +x "${root}/src/git.sh"
  tmux set-option -gq "status-right" "#{git}"
  bash "${root}/git-revamped.tmux"
  local job
  job="$(cat "$(_mock_opt_file status-right)")"
  job="${job#\#(}"
  job="${job%)}"

  # Act
  run sh -c "${job//\#\{pane_current_path\}/${TEST_TMPDIR}}"

  # Assert
  [[ "${output}" == "ran status" ]]
}
