# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `@git_revamped_render 'options'` replaces the `#()` calls with pane option
  reads, written for every pane by one background process per server every
  `@git_revamped_interval` seconds, 5 by default. A pane outside a repository keeps its last value,
  so the pill no longer blinks when a program works in another directory.
- `@git_revamped_icons`, a default icon set for every segment. `ascii` keeps
  the plain characters; `nerd` uses Nerd Font glyphs. A per-segment icon option
  still overrides it.
- `@git_revamped_before` and `@git_revamped_after`, placed around the status
  and the branch only when there is something to show, so a theme can draw a
  pill that disappears outside a repository.
- `@git_revamped_web_interval`, a separate cache for the provider segment, 300
  seconds by default, so the GitHub and GitLab APIs are not called on every
  five-second status refresh.
- `@git_revamped_web_zero`. Setting it to `0` hides provider counts that are
  zero.
- A CI label set to an empty string shows the CI icon alone, without a
  trailing space.
- The provider segment speaks to GitHub as the account the project names: the
  login in its `user.email` noreply address, then the `@git_revamped_gh_accounts`
  owner map, then the active `gh` account.
- `@git_revamped_reset`, the style that closes every segment. It defaults to
  `#[default]` as before; a plain foreground keeps the background a pill set.

### Changed

- The options-mode background process reads every option it needs in one tmux
  call per tick, sends its cache writes and published values in a second, and
  keeps its functions out of the environment of the commands it runs. Options
  mode ticks every `@git_revamped_interval` seconds.

### Fixed

- The worktree and clean flags printed their text twice, as `wt wt` and
  `ok ok`. They now render their icon once.
- The status and branch jobs passed the pane path unquoted, so a repository
  whose path holds a space, such as `~/Work/Acme Corp/app`, rendered nothing.
  The path is now quoted.
- The provider calls ran in the status worker's working directory rather than
  the repository's, so `gh` and `glab` counted another repository or nothing at
  all. They now run inside the repository of the active pane.
- A remote using an SSH host alias, such as `git@github-work:owner/repo.git`,
  was not recognised as GitHub or GitLab, so its provider segment never ran.
  The alias is now resolved through `ssh -G`.

## [1.2.0] - 2026-06-29

### Added

- CI check status for the head commit in the opt-in web path. The `gh pr checks`
  or `glab ci status` result renders as a green, red, or yellow `CI` segment.
  Toggle it with `@git_revamped_ci`.
- lazygit popup, branch switcher menu, and open-in-browser actions, bound to keys
  only when `@git_revamped_key_lazygit`, `@git_revamped_key_menu`, or
  `@git_revamped_key_browse` is set. Each action feature-detects its tool and runs
  only inside a repository.
- Upstream ref segment with a no-upstream `local` warning, opt-in through
  `@git_revamped_upstream`.
- Base-divergence segment showing commits ahead of a base branch, enabled by
  setting `@git_revamped_base_branch`.
- Linked-worktree indicator and dirty-submodule count, opt-in through
  `@git_revamped_worktree` and `@git_revamped_submodule`.
- Clean-tree indicator, opt-in through `@git_revamped_clean`.
- `doctor` subcommand that reports the version, repository state, detected tools,
  provider, and popup support.

### Changed

- Detached HEAD now shows the short commit SHA and the nearest tag instead of the
  literal `HEAD`.
- An in-progress rebase or am now shows its step as `X/Y` when the counters are
  available.
- Background autofetch now prunes deleted remote branches and updates tags.

## [1.1.1] - 2026-06-23

### Changed

- Reviewed the git module against catppuccin's gitmux discussion (#581). The
  branch segment already reports ahead and behind counts, staged, modified, and
  untracked totals, and special states such as rebase or merge. Segment colors
  are named colors that survive the tmux 3.7 format-expansion change. No code
  change needed.

## [1.1.0] - 2026-06-20

### Added

- GitHub bug count in the web segment. Issues assigned to you and labeled `bug`
  render as a separate red `B` segment and are excluded from the issue count, so
  the two never double-count the same issue.

### Fixed

- GitLab review and issue counts in the web segment, previously hardcoded to
  zero, now report assigned merge requests under review and open issues.

## [1.0.0] - 2026-06-20

### Added

- Git status placeholders `#{git}` and `#{git_branch}`, scoped to the active
  pane's path and empty outside a repository.
- Core status: branch with length limit, changed files, inserted and deleted
  lines, and untracked files, each with a configurable color and icon.
- Optional segments: stash count, ahead and behind counts, last-commit age, and
  GitHub or GitLab pull-request, review, and issue counts.
- Non-blocking design: the full status is cached per directory in tmux server
  options and refreshed by a detached worker, with no temp files.
