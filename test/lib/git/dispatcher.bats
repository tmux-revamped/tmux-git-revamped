#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GIT_REVAMPED_GIT_LOADED _GIT_REVAMPED_RENDER_LOADED _GIT_REVAMPED_ACTIONS_LOADED
  export CACHE_SYNC=1
  source "${BATS_TEST_DIRNAME}/../../../src/git.sh"
  _git_in_repo() { return 0; }
  _git_status() { printf '## main...origin/main [ahead 2, behind 1]\n M src/a\nM  src/b\n?? new1\n?? new2\n'; }
  _git_numstat() { printf '3\t1\tsrc/a\n4\t0\tsrc/b\n'; }
  _git_branch() { echo "main"; }
  _git_user_email() { echo ""; }
  _gh_token_for() { echo ""; }
  _ssh_hostname() { echo ""; }
}

teardown() {
  cleanup_test_environment
}

@test "git.sh dispatcher - functions are defined" {
  function_exists main
  function_exists git_build_status
  function_exists git_render_status
  function_exists git_web_segment
  function_exists git_ci_segment
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

@test "git.sh dispatcher - upstream segment is opt-in and reads the header" {
  set_tmux_option "@git_revamped_upstream" "1"
  run git_build_status /repo
  [[ "${output}" == *"#[fg=cyan]-> origin/main#[default]"* ]]
}

@test "git.sh dispatcher - no-upstream warning fires for a local branch" {
  set_tmux_option "@git_revamped_upstream" "1"
  _git_status() { printf '## solo\n M src/a\n'; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=yellow]! local#[default]"* ]]
}

@test "git.sh dispatcher - detached HEAD shows short sha and nearest tag" {
  _git_status() { printf '## HEAD (no branch)\n M src/a\n'; }
  _git_short_sha() { echo "abc1234"; }
  _git_describe() { echo "v1.2.0"; }
  run git_build_status /repo
  [[ "${output}" == "abc1234 v1.2.0#[default]"* ]]
}

@test "git.sh dispatcher - detached HEAD without a tag shows the sha alone" {
  _git_status() { printf '## HEAD (no branch)\n'; }
  _git_short_sha() { echo "deadbee"; }
  _git_describe() { echo ""; }
  run git_build_status /repo
  [[ "${output}" == "deadbee#[default]" ]]
}

@test "git.sh dispatcher - upstream is suppressed when detached" {
  set_tmux_option "@git_revamped_upstream" "1"
  _git_status() { printf '## HEAD (no branch)\n'; }
  _git_short_sha() { echo "deadbee"; }
  _git_describe() { echo ""; }
  run git_build_status /repo
  [[ "${output}" != *"local"* ]]
  [[ "${output}" != *"->"* ]]
}

@test "git.sh dispatcher - worktree indicator is opt-in" {
  set_tmux_option "@git_revamped_worktree" "1"
  _git_dir() { echo "/repo/.git/worktrees/feat"; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=cyan]wt#[default]"* ]]
}

@test "git.sh dispatcher - worktree indicator absent for the main worktree" {
  set_tmux_option "@git_revamped_worktree" "1"
  _git_dir() { echo "/repo/.git"; }
  run git_build_status /repo
  [[ "${output}" != *"wt wt"* ]]
}

@test "git.sh dispatcher - base divergence shows commits ahead of the base" {
  set_tmux_option "@git_revamped_base_branch" "main"
  _git_base_count() { echo "4"; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=magenta]~> 4#[default]"* ]]
}

@test "git.sh dispatcher - base divergence is hidden when there are no commits" {
  set_tmux_option "@git_revamped_base_branch" "main"
  _git_base_count() { echo "0"; }
  run git_build_status /repo
  [[ "${output}" != *"~>"* ]]
}

@test "git.sh dispatcher - submodule dirty count is opt-in" {
  set_tmux_option "@git_revamped_submodule" "1"
  _git_submodule_status() { printf '+1111 a (v1)\n 2222 b (v2)\n'; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=yellow]sub 1#[default]"* ]]
}

@test "git.sh dispatcher - clean indicator is opt-in and shows on a clean tree" {
  set_tmux_option "@git_revamped_clean" "1"
  _git_status() { printf '## main...origin/main\n'; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=green]ok#[default]"* ]]
}

@test "git.sh dispatcher - clean indicator is hidden on a dirty tree" {
  set_tmux_option "@git_revamped_clean" "1"
  run git_build_status /repo
  [[ "${output}" != *"ok ok"* ]]
}

@test "git.sh dispatcher - web segment adds provider counts when enabled" {
  set_tmux_option "@git_revamped_web" "1"
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { echo "2"; }
  _gh_review_count() { echo "1"; }
  _gh_issue_count() { echo "4"; }
  _gh_bug_count() { echo "1"; }
  _gh_ci_buckets() { echo ""; }
  run git_build_status "${BATS_TEST_TMPDIR}"
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
  _gh_ci_buckets() { echo ""; }
  run git_web_segment "${BATS_TEST_TMPDIR}"
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
  _glab_ci_status() { echo ""; }
  run git_web_segment "${BATS_TEST_TMPDIR}"
  [[ "${output}" == *"#[fg=cyan]PR 5#[default]"* ]]
  [[ "${output}" == *"#[fg=magenta]R 2#[default]"* ]]
  [[ "${output}" == *"#[fg=blue]I 3#[default]"* ]]
  [[ "${output}" == *"#[fg=red]B 0#[default]"* ]]
}

@test "git.sh dispatcher - CI status renders in the web path for github" {
  set_tmux_option "@git_revamped_web" "1"
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { echo "0"; }
  _gh_review_count() { echo "0"; }
  _gh_issue_count() { echo "0"; }
  _gh_bug_count() { echo "0"; }
  _gh_ci_buckets() { printf 'pass\nfail\n'; }
  run git_web_segment "${BATS_TEST_TMPDIR}"
  [[ "${output}" == *"#[fg=red]CI fail#[default]"* ]]
}

@test "git.sh dispatcher - CI status renders in the web path for gitlab" {
  _git_remote_url() { echo "git@gitlab.com:o/r.git"; }
  has_command() { [[ "$1" == "glab" ]]; }
  _glab_mr_count() { echo "0"; }
  _glab_review_count() { echo "0"; }
  _glab_issue_count() { echo "0"; }
  _glab_ci_status() { echo "Pipeline running"; }
  run git_web_segment "${BATS_TEST_TMPDIR}"
  [[ "${output}" == *"#[fg=yellow]CI pending#[default]"* ]]
}

@test "git.sh dispatcher - CI status can be disabled inside the web path" {
  set_tmux_option "@git_revamped_ci" "0"
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { echo "0"; }
  _gh_review_count() { echo "0"; }
  _gh_issue_count() { echo "0"; }
  _gh_bug_count() { echo "0"; }
  _gh_ci_buckets() { printf 'fail\n'; }
  run git_web_segment "${BATS_TEST_TMPDIR}"
  [[ "${output}" != *"CI"* ]]
}

@test "git.sh dispatcher - git_ci_segment is empty for a provider without a CLI mapping" {
  run git_ci_segment /repo unknown
  [[ -z "${output}" ]]
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

@test "git.sh dispatcher - lazygit subcommand opens a popup through the tmux seam" {
  has_command() { return 0; }
  _tmux_version() { echo "3.4"; }
  _tmux() { echo "$*" >> "${BATS_TEST_TMPDIR}/tmux"; }
  run main lazygit /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/tmux")" == *"display-popup"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/tmux")" == *"lazygit"* ]]
}

@test "git.sh dispatcher - menu subcommand builds a branch menu through the tmux seam" {
  has_command() { return 0; }
  _git_is_clean() { return 0; }
  _git_branch_list() { printf 'main\nfeature\n'; }
  _tmux() { echo "$*" >> "${BATS_TEST_TMPDIR}/tmux"; }
  run main menu /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/tmux")" == *"display-menu"* ]]
  [[ "$(cat "${BATS_TEST_TMPDIR}/tmux")" == *"feature"* ]]
}

@test "git.sh dispatcher - checkout subcommand drives the checkout seam" {
  _git_checkout() { echo "$1 $2" >> "${BATS_TEST_TMPDIR}/co"; }
  run main checkout /repo feature
  [[ "$(cat "${BATS_TEST_TMPDIR}/co")" == "/repo feature" ]]
}

@test "git.sh dispatcher - browse subcommand drives the provider opener" {
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_browse() { echo "$1" >> "${BATS_TEST_TMPDIR}/browse"; }
  run main browse /repo
  [[ "$(cat "${BATS_TEST_TMPDIR}/browse")" == "/repo" ]]
}

@test "git.sh dispatcher - doctor subcommand prints a capability report" {
  run main doctor /repo
  [[ "${output}" == *"tmux-git-revamped doctor"* ]]
  [[ "${output}" == *"version: 1.2.0"* ]]
  [[ "${output}" == *"tool git:"* ]]
}

@test "git.sh dispatcher - unknown subcommand produces no output" {
  run main bogus
  [[ -z "${output}" ]]
}

@test "git.sh dispatcher - build is empty when the status is empty" {
  _git_status() { echo ""; }
  run git_build_status /repo
  [[ -z "${output}" ]]
}

@test "git.sh dispatcher - staged count is opt-in" {
  set_tmux_option "@git_revamped_staged" "1"
  run git_build_status /repo
  [[ "${output}" == *"#[fg=green]S 1#[default]"* ]]
}

@test "git.sh dispatcher - conflict count renders when present" {
  _git_status() { printf '## main\nUU a\n'; }
  run git_build_status /repo
  [[ "${output}" == *"#[fg=red]! 1#[default]"* ]]
}

@test "git.sh dispatcher - branch subcommand is empty when no branch resolves" {
  _git_branch() { echo ""; }
  run main branch /repo
  [[ -z "${output}" ]]
}

@test "git.sh - _git_fetch returns before the fetch it started finishes" {
  local shim="${BATS_TEST_TMPDIR}/bin"
  mkdir -p "${shim}"
  printf '#!/bin/sh\nsleep 6\n' > "${shim}/git"
  chmod +x "${shim}/git"

  local start end
  start="$(date +%s)"
  run bash -c 'PATH="'"${shim}"':${PATH}"; . "'"${BATS_TEST_DIRNAME}"'/../../../src/lib/git/git.sh" 2>/dev/null || true
    out=$(_git_fetch /tmp)
    printf "returned\n"'
  end="$(date +%s)"

  [[ "${output}" == *"returned"* ]]
  (( end - start < 5 ))
}

@test "git.sh dispatcher - status is wrapped in before and after when set" {
  set_tmux_option "@git_revamped_before" "<<"
  set_tmux_option "@git_revamped_after" ">>"

  run git_render_status /repo

  [[ "${output}" == "<<main#[default] "*">>" ]]
}

@test "git.sh dispatcher - nothing is wrapped outside a repository" {
  set_tmux_option "@git_revamped_before" "<<"
  set_tmux_option "@git_revamped_after" ">>"
  _git_in_repo() { return 1; }

  run git_render_status /not-a-repo

  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "git.sh dispatcher - status is unwrapped by default" {
  run git_render_status /repo

  [[ "${output}" == "main#[default] "* ]]
}

@test "git.sh dispatcher - branch command is wrapped when set" {
  set_tmux_option "@git_revamped_before" "<<"
  set_tmux_option "@git_revamped_after" ">>"

  run git_render_branch_cmd /repo

  [[ "${output}" == "<<main#[default]>>" ]]
}

@test "git.sh dispatcher - provider calls run inside the repository" {
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { pwd -P; }
  _gh_review_count() { echo "0"; }
  _gh_issue_count() { echo "0"; }
  _gh_bug_count() { echo "0"; }
  _gh_ci_buckets() { echo ""; }
  local repo
  repo="$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
  _git_web_counts() { echo "ran-in:$(pwd -P)"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == "ran-in:${repo}" ]]
}

@test "git.sh dispatcher - provider segment is empty when the directory is gone" {
  _git_remote_url() { echo "https://github.com/o/r"; }
  _git_web_counts() { echo "should-not-run"; }

  run git_web_segment "${BATS_TEST_TMPDIR}/absent"

  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}

@test "git.sh dispatcher - gh uses the account named by the project email" {
  _git_remote_url() { echo "git@github-onyx:tsos-tech/r.git"; }
  _ssh_hostname() { echo "github.com"; }
  _git_user_email() { echo "299237933+gfranco-c-buoy@users.noreply.github.com"; }
  _gh_token_for() { echo "token-for-${1}"; }
  _git_web_counts() { echo "token=${GH_TOKEN:-none}"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == "token=token-for-gfranco-c-buoy" ]]
}

@test "git.sh dispatcher - gh falls back to the owner map without a noreply email" {
  set_tmux_option "@git_revamped_gh_accounts" "tsos-tech=gfranco-onyxodds gufranco=gufranco"
  _git_remote_url() { echo "https://github.com/tsos-tech/r"; }
  _git_user_email() { echo "someone@example.com"; }
  _gh_token_for() { echo "token-for-${1}"; }
  _git_web_counts() { echo "token=${GH_TOKEN:-none}"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == "token=token-for-gfranco-onyxodds" ]]
}

@test "git.sh dispatcher - gh keeps the active account when nothing names one" {
  unset GH_TOKEN
  _git_remote_url() { echo "https://github.com/someone/r"; }
  _git_web_counts() { echo "token=${GH_TOKEN:-none}"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == "token=none" ]]
}

@test "git.sh dispatcher - an account without a token keeps the active account" {
  unset GH_TOKEN
  _git_remote_url() { echo "https://github.com/o/r"; }
  _git_user_email() { echo "ghost@users.noreply.github.com"; }
  _git_web_counts() { echo "token=${GH_TOKEN:-none}"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == "token=none" ]]
}

@test "git.sh dispatcher - a host alias resolves to its provider" {
  _git_remote_url() { echo "git@github-lineleap:LineLeap/api.git"; }
  _ssh_hostname() { [[ "${1}" == "github-lineleap" ]] && echo "github.com"; }
  _git_web_counts() { echo "provider=${2}"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == "provider=github" ]]
}

@test "git.sh dispatcher - zero provider counts can be hidden" {
  set_tmux_option "@git_revamped_web_zero" "0"
  set_tmux_option "@git_revamped_ci" "0"
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { echo "2"; }
  _gh_review_count() { echo "0"; }
  _gh_issue_count() { echo "0"; }
  _gh_bug_count() { echo "0"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == " #[fg=cyan]PR 2#[default]" ]]
}

@test "git.sh dispatcher - zero provider counts show by default" {
  set_tmux_option "@git_revamped_ci" "0"
  _git_remote_url() { echo "https://github.com/o/r"; }
  has_command() { [[ "$1" == "gh" ]]; }
  _gh_pr_count() { echo "0"; }
  _gh_review_count() { echo "0"; }
  _gh_issue_count() { echo "0"; }
  _gh_bug_count() { echo "0"; }

  run git_web_segment "${BATS_TEST_TMPDIR}"

  [[ "${output}" == *"PR 0"* ]]
  [[ "${output}" == *"B 0"* ]]
}

@test "git.sh dispatcher - provider interval defaults to five minutes" {
  run git_web_interval

  [[ "${output}" == "300" ]]
}

@test "git.sh dispatcher - an invalid provider interval falls back to the default" {
  set_tmux_option "@git_revamped_web_interval" "soon"

  run git_web_interval

  [[ "${output}" == "300" ]]
}

@test "git.sh dispatcher - the provider segment is cached under its own key" {
  set_tmux_option "@git_revamped_web" "1"
  local calls="${BATS_TEST_TMPDIR}/calls"
  git_web_segment() { echo x >>"${calls}"; echo " #[fg=cyan]PR 1#[default]"; }

  git_build_status /repo >/dev/null
  git_build_status /repo >/dev/null

  run wc -l <"${calls}"
  [[ "${output// /}" == "1" ]]
}
