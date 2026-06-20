#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GIT_REVAMPED_GIT_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/git/git.sh"
}

teardown() {
  cleanup_test_environment
}

@test "git.sh - parse_branch reads the branch from the header" {
  [[ "$(parse_branch '## main...origin/main [ahead 1]')" == "main" ]]
  [[ "$(parse_branch '## feature/login...origin/feature/login')" == "feature/login" ]]
  [[ "$(parse_branch '## release')" == "release" ]]
}

@test "git.sh - parse_ahead and parse_behind read the counts" {
  [[ "$(parse_ahead '## main...origin/main [ahead 3, behind 2]')" == "3" ]]
  [[ "$(parse_behind '## main...origin/main [ahead 3, behind 2]')" == "2" ]]
  [[ "$(parse_ahead '## main')" == "0" ]]
  [[ "$(parse_behind '## main')" == "0" ]]
}

@test "git.sh - count_modified skips header and untracked lines" {
  local txt=$'## main\n M src/a\nM  src/b\n?? new'
  [[ "$(count_modified "${txt}")" == "2" ]]
}

@test "git.sh - count_untracked counts question-mark lines" {
  local txt=$'## main\n?? a\n?? b\n M c'
  [[ "$(count_untracked "${txt}")" == "2" ]]
}

@test "git.sh - parse_diffstat sums numstat" {
  local txt=$'3\t1\tsrc/a\n2\t0\tsrc/b'
  [[ "$(parse_diffstat "${txt}")" == "2 5 1" ]]
}

@test "git.sh - truncate_branch shortens past the limit" {
  [[ "$(truncate_branch short 25)" == "short" ]]
  [[ "$(truncate_branch verylongbranch 5)" == "veryl..." ]]
  [[ "$(truncate_branch name bogus)" == "name" ]]
}

@test "git.sh - relative_time scales minutes, hours, days" {
  [[ "$(relative_time 1800 0)" == "30m" ]]
  [[ "$(relative_time 3600 0)" == "1h" ]]
  [[ "$(relative_time 172800 0)" == "2d" ]]
  [[ -z "$(relative_time x y)" ]]
}

@test "git.sh - provider_from_url recognizes hosts" {
  [[ "$(provider_from_url 'https://github.com/o/r')" == "github" ]]
  [[ "$(provider_from_url 'git@gitlab.com:o/r.git')" == "gitlab" ]]
  [[ -z "$(provider_from_url 'https://bitbucket.org/o/r')" ]]
}

@test "git.sh - is_git_repo is false for a non-repo path" {
  _git_in_repo() { return 1; }
  run is_git_repo /tmp
  [[ "${status}" -ne 0 ]]
}

@test "git.sh - host-probe seams are callable" {
  run _git_in_repo /tmp
  run _git_branch /tmp
  run _git_status /tmp
  run _git_numstat /tmp
  run _git_stash_count /tmp
  run _git_last_commit_ts /tmp
  run _git_remote_url /tmp
  run _git_now
  run _gh_pr_count
  run _gh_review_count
  run _gh_issue_count
  run _glab_mr_count
  true
}
