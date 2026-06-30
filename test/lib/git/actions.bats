#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GIT_REVAMPED_GIT_LOADED _GIT_REVAMPED_ACTIONS_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/git/actions.sh"
  is_git_repo() { return 0; }
  _rec() { echo "$*" >> "${BATS_TEST_TMPDIR}/rec"; }
}

teardown() {
  cleanup_test_environment
}

@test "actions.sh - functions are defined" {
  function_exists git_action_lazygit
  function_exists git_action_menu
  function_exists git_action_checkout
  function_exists git_action_browse
  function_exists git_doctor
  function_exists _tmux
}

@test "actions.sh - _tmux routes to tmux" {
  run _tmux display-message hi
  [[ "${status}" -eq 0 ]]
}

@test "actions.sh - _tmux_version reads the version seam" {
  run _tmux_version
  [[ "${status}" -eq 0 ]]
}

@test "actions.sh - tmux_has_popup gates on the version" {
  run tmux_has_popup ""
  [[ "${status}" -ne 0 ]]
  run tmux_has_popup "tmux 4.0"
  [[ "${status}" -eq 0 ]]
  run tmux_has_popup "3.2"
  [[ "${status}" -eq 0 ]]
  run tmux_has_popup "3.1"
  [[ "${status}" -ne 0 ]]
  run tmux_has_popup "."
  [[ "${status}" -ne 0 ]]
  run tmux_has_popup "3."
  [[ "${status}" -ne 0 ]]
}

@test "actions.sh - interactive git seams run without network" {
  run _git_is_clean /tmp
  run _git_branch_list /tmp
  run _git_checkout /tmp nonexistent-branch-xyz
  true
}

@test "actions.sh - _gh_browse runs through a stubbed gh" {
  gh() { return 0; }
  run _gh_browse /tmp
  [[ "${status}" -eq 0 ]]
}

@test "actions.sh - _glab_browse runs through a stubbed glab" {
  glab() { return 0; }
  run _glab_browse /tmp
  [[ "${status}" -eq 0 ]]
}

@test "actions.sh - lazygit opens a popup on tmux 3.2+" {
  has_command() { return 0; }
  _tmux_version() { echo "3.4"; }
  _tmux() { _rec "$@"; }
  git_action_lazygit /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"display-popup"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"lazygit"* ]]
}

@test "actions.sh - lazygit falls back to a new window below tmux 3.2" {
  has_command() { return 0; }
  _tmux_version() { echo "3.1"; }
  _tmux() { _rec "$@"; }
  git_action_lazygit /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"new-window"* ]]
}

@test "actions.sh - lazygit is a no-op outside a repo" {
  is_git_repo() { return 1; }
  _tmux() { _rec "$@"; }
  git_action_lazygit /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - lazygit is a no-op when lazygit is missing" {
  has_command() { return 1; }
  _tmux() { _rec "$@"; }
  git_action_lazygit /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - menu builds a branch menu when the tree is clean" {
  has_command() { return 0; }
  _git_is_clean() { return 0; }
  _git_branch_list() { printf 'main\n\nfeature\n'; }
  _tmux() { _rec "$@"; }
  git_action_menu /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"display-menu"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"main"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"feature"* ]]
}

@test "actions.sh - menu refuses when the tree is dirty" {
  has_command() { return 0; }
  _git_is_clean() { return 1; }
  _tmux() { _rec "$@"; }
  git_action_menu /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"display-message"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == *"dirty"* ]]
}

@test "actions.sh - menu is a no-op with no branches" {
  has_command() { return 0; }
  _git_is_clean() { return 0; }
  _git_branch_list() { echo ""; }
  _tmux() { _rec "$@"; }
  git_action_menu /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - menu is a no-op outside a repo" {
  is_git_repo() { return 1; }
  _tmux() { _rec "$@"; }
  git_action_menu /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - menu is a no-op when git is missing" {
  has_command() { return 1; }
  _tmux() { _rec "$@"; }
  git_action_menu /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - checkout drives the checkout seam" {
  _git_checkout() { _rec "$1" "$2"; }
  git_action_checkout /repo feature
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == "/repo feature" ]]
}

@test "actions.sh - checkout is a no-op without a branch" {
  _git_checkout() { _rec "$1" "$2"; }
  git_action_checkout /repo ""
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - checkout is a no-op outside a repo" {
  is_git_repo() { return 1; }
  _git_checkout() { _rec "$1" "$2"; }
  git_action_checkout /repo feature
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - browse opens github through gh" {
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_browse() { _rec "gh" "$1"; }
  git_action_browse /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == "gh /repo" ]]
}

@test "actions.sh - browse opens gitlab through glab" {
  _git_remote_url() { echo "git@gitlab.com:o/r.git"; }
  has_command() { [[ "$1" == "glab" ]]; }
  _glab_browse() { _rec "glab" "$1"; }
  git_action_browse /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/rec")" == "glab /repo" ]]
}

@test "actions.sh - browse is a no-op for an unknown provider" {
  _git_remote_url() { echo "https://example.com/o/r"; }
  has_command() { return 0; }
  _gh_browse() { _rec gh; }
  _glab_browse() { _rec glab; }
  git_action_browse /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - browse is a no-op outside a repo" {
  is_git_repo() { return 1; }
  _gh_browse() { _rec gh; }
  git_action_browse /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/rec" ]]
}

@test "actions.sh - _doctor_tool reports found and missing" {
  has_command() { return 0; }
  [[ "$(_doctor_tool git)" == "tool git: found" ]]
  has_command() { return 1; }
  [[ "$(_doctor_tool nope)" == "tool nope: missing" ]]
}

@test "actions.sh - git_doctor reports a repo with a provider" {
  is_git_repo() { return 0; }
  _git_remote_url() { echo "https://github.com/o/r"; }
  _tmux_version() { echo "3.4"; }
  run git_doctor /repo
  [[ "${output}" == *"tmux-git-revamped doctor"* ]]
  [[ "${output}" == *"repo: yes /repo"* ]]
  [[ "${output}" == *"provider: github"* ]]
  [[ "${output}" == *"popup: yes"* ]]
}

@test "actions.sh - git_doctor reports a repo without a provider" {
  is_git_repo() { return 0; }
  _git_remote_url() { echo ""; }
  _tmux_version() { echo "3.1"; }
  run git_doctor /repo
  [[ "${output}" == *"provider: none"* ]]
  [[ "${output}" == *"popup: no"* ]]
}

@test "actions.sh - git_doctor reports outside a repo" {
  is_git_repo() { return 1; }
  run git_doctor /repo
  [[ "${output}" == *"repo: no /repo"* ]]
  [[ "${output}" != *"provider:"* ]]
}
