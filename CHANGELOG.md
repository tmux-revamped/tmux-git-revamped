# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
