#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GIT_REVAMPED_GIT_LOADED _GIT_REVAMPED_RENDER_LOADED
  export CACHE_SYNC=1
  source "${BATS_TEST_DIRNAME}/../../../src/git.sh"
  _git_in_repo() { return 0; }
  _git_status() { printf '## main...origin/main [ahead 2, behind 1]\n M src/a\nM  src/b\n?? new1\n?? new2\n'; }
  _git_numstat() { printf '3\t1\tsrc/a\n4\t0\tsrc/b\n'; }
  _git_branch() { echo "main"; }
}

teardown() {
  cleanup_test_environment
}

@test "git.sh dispatcher - functions are defined" {
  function_exists main
  function_exists git_build_status
  function_exists git_render_status
  function_exists git_web_segment
}

@test "git.sh dispatcher - build shows branch, changes, and untracked by default" {
  run git_build_status /repo
  [[ "${output}" == "main#[default] #[fg=yellow]~ 2#[default] #[fg=green]+ 7#[default] #[fg=red]- 1#[default] #[fg=blue]? 2#[default]" ]]
}

@test "git.sh dispatcher - untracked can be turned off" {
  set_tmux_option "@git_revamped_untracked" "0"
  run git_build_status /repo
  [[ "${output}" != *"? 2"* ]]
}

@test "git.sh dispatcher - ahead and behind are opt-in" {
  set_tmux_option "@git_revamped_ahead_behind" "1"
  run git_build_status /repo
  [[ "${output}" == *"#[fg=green]^ 2#[default]"* ]]
  [[ "${output}" == *"#[fg=yellow]v 1#[default]"* ]]
}

@test "git.sh dispatcher - stash is opt-in" {
  set_tmux_option "@git_revamped_stash" "1"
  _git_stash_count() { echo "3"; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=magenta]\$ 3#[default]"* ]]
}

@test "git.sh dispatcher - last commit age is opt-in" {
  set_tmux_option "@git_revamped_last_commit" "1"
  _git_last_commit_ts() { echo "0"; }
  _git_now() { echo "1800"; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=blue]@ 30m#[default]"* ]]
}

@test "git.sh dispatcher - web segment adds provider counts when enabled" {
  set_tmux_option "@git_revamped_web" "1"
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { echo "2"; }
  _gh_review_count() { echo "1"; }
  _gh_issue_count() { echo "4"; }
  _gh_bug_count() { echo "1"; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=cyan]PR 2#[default]"* ]]
  [[ "${output}" == *"#[fg=magenta]R 1#[default]"* ]]
  [[ "${output}" == *"#[fg=blue]I 3#[default]"* ]]
  [[ "${output}" == *"#[fg=red]B 1#[default]"* ]]
}

@test "git.sh dispatcher - github issue count never goes negative" {
  set_tmux_option "@git_revamped_web" "1"
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { echo "0"; }
  _gh_review_count() { echo "0"; }
  _gh_issue_count() { echo "1"; }
  _gh_bug_count() { echo "3"; }
  run git_web_segment /repo
  [[ "${output}" == *"#[fg=blue]I 0#[default]"* ]]
  [[ "${output}" == *"#[fg=red]B 3#[default]"* ]]
}

@test "git.sh dispatcher - web segment is empty for an unknown provider" {
  _git_remote_url() { echo "https://example.com/o/r"; }
  run git_web_segment /repo
  [[ -z "${output}" ]]
}

@test "git.sh dispatcher - web segment supports gitlab" {
  _git_remote_url() { echo "git@gitlab.com:o/r.git"; }
  has_command() { [[ "$1" == "glab" ]]; }
  _glab_mr_count() { echo "5"; }
  _glab_review_count() { echo "2"; }
  _glab_issue_count() { echo "3"; }
  run git_web_segment /repo
  [[ "${output}" == *"#[fg=cyan]PR 5#[default]"* ]]
  [[ "${output}" == *"#[fg=magenta]R 2#[default]"* ]]
  [[ "${output}" == *"#[fg=blue]I 3#[default]"* ]]
  [[ "${output}" == *"#[fg=red]B 0#[default]"* ]]
}

@test "git.sh dispatcher - status defaults to the working directory" {
  run main status
  [[ "${output}" == "main#[default]"* ]]
}

@test "git.sh dispatcher - status renders through the cache" {
  run main status /repo
  [[ "${output}" == "main#[default]"* ]]
  [[ "${output}" == *"? 2#[default]" ]]
}

@test "git.sh dispatcher - branch subcommand renders the branch" {
  run main branch /repo
  [[ "${output}" == "main#[default]" ]]
}

@test "git.sh dispatcher - refresh subcommand caches the build" {
  run main refresh /repo
  [[ "$(cache_get "$(_git_key /repo)")" == "main#[default]"* ]]
}

@test "git.sh dispatcher - status is empty outside a repo" {
  _git_in_repo() { return 1; }
  run main status /repo
  [[ -z "${output}" ]]
}

@test "git.sh - autofetch is skipped when disabled" {
  _git_fetch() { echo x >> "${BATS_TEST_TMPDIR}/fetched"; }
  set_tmux_option "@git_revamped_autofetch" "0"
  git_autofetch /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/fetched" ]]
}

@test "git.sh - autofetch fires when enabled and the throttle elapsed" {
  _git_fetch() { echo x >> "${BATS_TEST_TMPDIR}/fetched"; }
  _git_now() { echo 100000; }
  has_command() { return 0; }
  set_tmux_option "@git_revamped_autofetch" "1"
  git_autofetch /repo
  [[ -f "${BATS_TEST_TMPDIR}/fetched" ]]
}

@test "git.sh - autofetch is throttled within the interval" {
  _git_fetch() { echo x >> "${BATS_TEST_TMPDIR}/fetched"; }
  _git_now() { echo 100000; }
  has_command() { return 0; }
  set_tmux_option "@git_revamped_autofetch" "1"
  git_autofetch /repo
  rm -f "${BATS_TEST_TMPDIR}/fetched"
  git_autofetch /repo
  [[ ! -f "${BATS_TEST_TMPDIR}/fetched" ]]
}

@test "git.sh - _git_fetch seam is runnable" {
  run _git_fetch /nonexistent-repo-xyz
  true
}

@test "git.sh dispatcher - unknown subcommand produces no output" {
  run main bogus
  [[ -z "${output}" ]]
}
