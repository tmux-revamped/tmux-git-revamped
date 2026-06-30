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

@test "git.sh - parse_upstream reads the upstream ref or nothing" {
  [[ "$(parse_upstream '## main...origin/main [ahead 1]')" == "origin/main" ]]
  [[ "$(parse_upstream '## feature...fork/feature')" == "fork/feature" ]]
  [[ -z "$(parse_upstream '## main')" ]]
  [[ -z "$(parse_upstream '## HEAD (no branch)')" ]]
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

@test "git.sh - count_staged counts only index changes, not unstaged or conflicts" {
  local txt=$'## main\nM  a\n M b\nMM c\nA  d\nUU e\n?? f'
  [[ "$(count_staged "${txt}")" == "3" ]]
}

@test "git.sh - count_conflict counts unmerged paths" {
  local txt=$'## main\nUU a\nAA b\nM  c\n M d'
  [[ "$(count_conflict "${txt}")" == "2" ]]
  [[ "$(count_conflict $'## main\nM  a')" == "0" ]]
}

@test "git.sh - count_submodule_dirty counts plus-prefixed submodules" {
  local txt=$' 1111 sub-a (v1)\n+2222 sub-b (v2)\n+3333 sub-c (v3)\n-4444 sub-d'
  [[ "$(count_submodule_dirty "${txt}")" == "2" ]]
  [[ "$(count_submodule_dirty "")" == "0" ]]
}

@test "git.sh - _read_first_line reads a file or returns empty" {
  local d; d="$(mktemp -d)"
  printf '7\n9\n' > "${d}/n"
  [[ "$(_read_first_line "${d}/n")" == "7" ]]
  [[ -z "$(_read_first_line "${d}/missing")" ]]
  rm -rf "${d}"
}

@test "git.sh - _rebase_progress reports step or empty" {
  local d; d="$(mktemp -d)"
  printf '2\n' > "${d}/msgnum"
  printf '5\n' > "${d}/end"
  [[ "$(_rebase_progress "${d}" msgnum end)" == " 2/5" ]]
  rm -f "${d}/end"
  [[ -z "$(_rebase_progress "${d}" msgnum end)" ]]
  rm -rf "${d}"
}

@test "git.sh - git_special_state detects in-progress operations" {
  local d
  d="$(mktemp -d)"
  [[ -z "$(git_special_state "${d}")" ]]
  touch "${d}/MERGE_HEAD"
  [[ "$(git_special_state "${d}")" == "merge" ]]
  rm -f "${d}/MERGE_HEAD"
  mkdir -p "${d}/rebase-merge"
  [[ "$(git_special_state "${d}")" == "rebase" ]]
  rm -rf "${d}/rebase-merge"
  touch "${d}/CHERRY_PICK_HEAD"
  [[ "$(git_special_state "${d}")" == "cherry-pick" ]]
  rm -f "${d}/CHERRY_PICK_HEAD"
  touch "${d}/REVERT_HEAD"
  [[ "$(git_special_state "${d}")" == "revert" ]]
  rm -f "${d}/REVERT_HEAD"
  touch "${d}/BISECT_LOG"
  [[ "$(git_special_state "${d}")" == "bisect" ]]
  rm -rf "${d}"
}

@test "git.sh - git_special_state annotates rebase-merge progress" {
  local d; d="$(mktemp -d)"
  mkdir -p "${d}/rebase-merge"
  printf '3\n' > "${d}/rebase-merge/msgnum"
  printf '8\n' > "${d}/rebase-merge/end"
  [[ "$(git_special_state "${d}")" == "rebase 3/8" ]]
  rm -rf "${d}"
}

@test "git.sh - git_special_state distinguishes am from rebase under rebase-apply" {
  local d; d="$(mktemp -d)"
  mkdir -p "${d}/rebase-apply"
  printf '1\n' > "${d}/rebase-apply/next"
  printf '4\n' > "${d}/rebase-apply/last"
  [[ "$(git_special_state "${d}")" == "rebase 1/4" ]]
  touch "${d}/rebase-apply/applying"
  [[ "$(git_special_state "${d}")" == "am 1/4" ]]
  rm -rf "${d}"
}

@test "git.sh - is_linked_worktree detects the worktrees path" {
  run is_linked_worktree "/repo/.git/worktrees/feature"
  [[ "${status}" -eq 0 ]]
  run is_linked_worktree "/repo/.git"
  [[ "${status}" -ne 0 ]]
}

@test "git.sh - detached_head_label combines sha and tag" {
  [[ "$(detached_head_label abc123 v1.2.0)" == "abc123 v1.2.0" ]]
  [[ "$(detached_head_label abc123 '')" == "abc123" ]]
  [[ -z "$(detached_head_label '' v1.2.0)" ]]
}

@test "git.sh - ci_status_from_buckets prioritizes fail then pending" {
  [[ "$(ci_status_from_buckets $'pass\nfail\npending')" == "fail" ]]
  [[ "$(ci_status_from_buckets $'pass\npending')" == "pending" ]]
  [[ "$(ci_status_from_buckets $'pass\npass')" == "pass" ]]
  [[ -z "$(ci_status_from_buckets '')" ]]
}

@test "git.sh - ci_status_from_glab maps status words" {
  [[ "$(ci_status_from_glab 'Pipeline failed')" == "fail" ]]
  [[ "$(ci_status_from_glab 'status: running')" == "pending" ]]
  [[ "$(ci_status_from_glab 'success')" == "pass" ]]
  [[ -z "$(ci_status_from_glab 'unknown thing')" ]]
  [[ -z "$(ci_status_from_glab '')" ]]
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

@test "git.sh - host-probe seams are callable without touching the network" {
  gh() { echo ""; }
  glab() { echo ""; }
  run _git_in_repo /tmp
  run _git_branch /tmp
  run _git_status /tmp
  run _git_numstat /tmp
  run _git_stash_count /tmp
  run _git_last_commit_ts /tmp
  run _git_remote_url /tmp
  run _git_dir /tmp
  run _git_short_sha /tmp
  run _git_describe /tmp
  run _git_base_count /tmp main
  run _git_submodule_status /tmp
  run _git_now
  run _gh_pr_count
  run _gh_review_count
  run _gh_issue_count
  run _gh_bug_count
  run _gh_ci_buckets
  run _glab_mr_count
  run _glab_review_count
  run _glab_issue_count
  run _glab_ci_status
  true
}
