# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
