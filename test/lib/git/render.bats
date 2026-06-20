#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../helpers.bash"

setup() {
  setup_test_environment
  unset _GIT_REVAMPED_RENDER_LOADED
  source "${BATS_TEST_DIRNAME}/../../../src/lib/git/render.sh"
}

teardown() {
  cleanup_test_environment
}

@test "render.sh - _git_default_color covers the segments" {
  [[ "$(_git_default_color changed)" == "#[fg=yellow]" ]]
  [[ "$(_git_default_color insertions)" == "#[fg=green]" ]]
  [[ "$(_git_default_color deletions)" == "#[fg=red]" ]]
  [[ "$(_git_default_color pr)" == "#[fg=cyan]" ]]
  [[ -z "$(_git_default_color other)" ]]
}

@test "render.sh - _git_default_icon covers the segments" {
  [[ "$(_git_default_icon insertions)" == "+" ]]
  [[ "$(_git_default_icon deletions)" == "-" ]]
  [[ "$(_git_default_icon untracked)" == "?" ]]
  [[ "$(_git_default_icon pr)" == "PR" ]]
  [[ -z "$(_git_default_icon other)" ]]
}

@test "render.sh - git_render_count uses defaults then options" {
  [[ "$(git_render_count changed 4)" == "#[fg=yellow]~ 4#[default]" ]]
  set_tmux_option "@git_revamped_changed_color" "#[fg=red]"
  set_tmux_option "@git_revamped_changed_icon" "M"
  [[ "$(git_render_count changed 4)" == "#[fg=red]M 4#[default]" ]]
}

@test "render.sh - git_render_count omits an empty icon" {
  [[ "$(git_render_count none 4)" == "4#[default]" ]]
}

@test "render.sh - git_render_branch is plain by default" {
  [[ "$(git_render_branch main)" == "main#[default]" ]]
  set_tmux_option "@git_revamped_branch_icon" "B"
  set_tmux_option "@git_revamped_branch_color" "#[fg=blue]"
  [[ "$(git_render_branch main)" == "#[fg=blue]B main#[default]" ]]
}

@test "render.sh - git_render_count passes a named color through verbatim" {
  set_tmux_option "@git_revamped_deletions_color" "#[fg=red]"
  [[ "$(git_render_count deletions 3)" == *"#[fg=red]"* ]]
}

@test "render.sh - git_render_count passes a 256 colour spec through verbatim" {
  set_tmux_option "@git_revamped_deletions_color" "#[fg=colour203]"
  [[ "$(git_render_count deletions 3)" == *"#[fg=colour203]"* ]]
}

@test "render.sh - git_render_count passes a hex color through verbatim" {
  set_tmux_option "@git_revamped_deletions_color" "#[fg=#f38ba8]"
  [[ "$(git_render_count deletions 3)" == *"#[fg=#f38ba8]"* ]]
}

@test "render.sh - git_render_count passes a hex fg and bg pair through verbatim" {
  set_tmux_option "@git_revamped_deletions_color" "#[fg=#f38ba8,bg=#1e1e2e]"
  [[ "$(git_render_count deletions 3)" == *"#[fg=#f38ba8,bg=#1e1e2e]"* ]]
}

@test "render.sh - git_render_count passes a bright named color through verbatim" {
  set_tmux_option "@git_revamped_deletions_color" "#[fg=brightred]"
  [[ "$(git_render_count deletions 3)" == *"#[fg=brightred]"* ]]
}
