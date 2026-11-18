#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031,SC2154

# shellcheck source=test/tmux_helpers.bash
source "${BATS_TEST_DIRNAME}/../tmux_helpers.bash"

wait_for() {
  local delay
  for delay in 0.01 0.02 0.05 0.1 0.1 0.2 0.2 0.5 0.5 1 1 1 2 2; do
    "$@" && return 0
    sleep "${delay}"
  done
  "$@" && return 0
  command tmux -S "${HOST}" capture-pane -p -t host || :
  return 1
}

attached() {
  local clients
  clients=$(tmux list-clients -F x 2>/dev/null)
  [[ -n "${clients}" ]]
}

host_shows() {
  local screen
  screen=$(command tmux -S "${HOST}" capture-pane -p -t host)
  [[ "${screen}" == *"$1"* ]]
}

said() {
  local messages
  messages=$(tmux show-messages)
  [[ "${messages}" == *"$1"* ]]
}

on_branch() {
  local now
  now=$(git -C "${REPO}" branch --show-current)
  [[ "${now}" == "$1" ]]
}

browsed() {
  [[ -s "${BATS_TEST_TMPDIR}/gh.calls" ]]
}

stand_in() {
  printf '#!/bin/sh\nprintf "%%s\\n" "%s stand-in running in $(pwd -P)"\nread -r stand_in_wait\n' "$1" >"${STUBS}/$1"
  chmod +x "${STUBS}/$1"
}

gh_answers() {
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s"\nexit %s\n' "${BATS_TEST_TMPDIR}/gh.calls" "$1" >"${STUBS}/gh"
  chmod +x "${STUBS}/gh"
}

without_git_tools() {
  local folder old_ifs="${IFS}"
  FARM="${BATS_TEST_TMPDIR}/farm"
  mkdir -p "${FARM}"
  IFS=:
  for folder in ${PATH}; do
    [[ -d "${folder}" ]] || continue
    ln -s "${folder}"/* "${FARM}/" 2>/dev/null || :
  done
  IFS="${old_ifs}"
  rm -f "${FARM}/lazygit" "${FARM}/gh" "${FARM}/glab"
  PATH="${STUBS}:${FARM}"
}

repository() {
  REPO="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "${REPO}"
  git -C "${REPO}" init -q -b main
  git -C "${REPO}" -c user.name=Octocat -c user.email= commit -q --allow-empty -m first
  git -C "${REPO}" branch feature
  git -C "${REPO}" remote add origin https://github.com/octocat/Hello-World.git
  REPO="$(cd "${REPO}" && pwd -P)"
}

setup() {
  unset BASH_ENV
  ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  STUBS="${BATS_TEST_TMPDIR}/stubs"
  export HOME="${BATS_TEST_TMPDIR}/home"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  mkdir -p "${HOME}" "${STUBS}"
  HOST="${TMUX_SOCKET}-host"
  without_git_tools
  repository
}

serve() {
  cd "$1" || return 1
  setup_tmux_server
  tmux set-option -g default-command "env PS1='$ ' sh"
  tmux set-option -g @git_revamped_key_browse F1
  tmux set-option -g @git_revamped_key_lazygit F2
  command tmux -S "${HOST}" -f /dev/null new-session -d -s host -x 120 -y 40 \
    "env -u TMUX TERM=xterm-256color tmux -S '${TMUX_SOCKET}' attach-session -t test"
  wait_for attached
  tmux run-shell "'${ROOT}/git-revamped.tmux'"
}

teardown() {
  command tmux -S "${HOST}" kill-server 2>/dev/null || :
  rm -f "${HOST}"
  teardown_tmux_server
}

press() {
  local key
  for key in "$@"; do
    command tmux -S "${HOST}" send-keys -t host "${key}"
  done
}

@test "keys - prefix M-v lists the branches, and picking one checks it out" {
  # Arrange
  serve "${REPO}"
  press C-b M-v
  wait_for host_shows "git branches"
  wait_for host_shows "feature"

  # Act
  press Enter

  # Assert
  wait_for on_branch feature
}

@test "keys - prefix M-v outside a repository says so" {
  # Arrange
  serve "${HOME}"

  # Act
  press C-b M-v

  # Assert
  wait_for said "git-revamped: this pane is not in a git repository"
}

@test "keys - prefix M-v with uncommitted changes refuses to switch" {
  # Arrange
  : >"${REPO}/untracked"
  serve "${REPO}"

  # Act
  press C-b M-v

  # Assert
  wait_for said "git-revamped: working tree dirty, not switching branch"
}

@test "keys - the browse key opens the repository page through gh" {
  # Arrange
  gh_answers 0
  serve "${REPO}"

  # Act
  press C-b F1

  # Assert
  wait_for browsed
  run cat "${BATS_TEST_TMPDIR}/gh.calls"
  [[ "${output}" == "browse" ]]
}

@test "keys - the browse key says so when gh fails, and the pane shows no raw error" {
  # Arrange
  gh_answers 4
  serve "${REPO}"

  # Act
  press C-b F1

  # Assert
  wait_for said "git-revamped: gh could not open the repository page"
  run tmux display-message -p -t test '#{pane_mode}'
  [[ "${output}" == "" ]]
}

@test "keys - the browse key names gh when it is not installed" {
  # Arrange
  serve "${REPO}"

  # Act
  press C-b F1

  # Assert
  wait_for said "git-revamped: gh is not installed"
}

@test "keys - the lazygit key opens lazygit in the repository" {
  # Arrange
  stand_in lazygit
  serve "${REPO}"

  # Act
  press C-b F2

  # Assert
  wait_for host_shows "lazygit stand-in running in"
  wait_for host_shows "${REPO##*/}"
}

@test "keys - the lazygit key says so when lazygit is not installed" {
  # Arrange
  serve "${REPO}"

  # Act
  press C-b F2

  # Assert
  wait_for said "git-revamped: lazygit is not installed"
}
