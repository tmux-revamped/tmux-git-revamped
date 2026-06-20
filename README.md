<div align="center">

<h1>tmux-git-revamped</h1>

**Git repository status in your tmux status bar, without ever blocking the render.**

[![Tests](https://github.com/gufranco/tmux-git-revamped/actions/workflows/tests.yml/badge.svg)](https://github.com/gufranco/tmux-git-revamped/actions/workflows/tests.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

**2** placeholders · **2** platforms · **77** tests · **95%+** coverage

The active pane's repository at a glance: branch, changed files, inserted and deleted lines, and untracked files, with optional stash, ahead and behind counts, last-commit age, and provider pull-request and issue counts. The full status can run slow work, so it is cached per directory and refreshed by a detached worker. The status line reads the cached value and returns instantly. No temp files are touched.

Built from [tmux-plugin-template](https://github.com/gufranco/tmux-plugin-template).

<table>
<tr>
<td><strong>Non-blocking</strong><br>The status renders instantly from a cached tmux user-option while a background worker runs git.</td>
<td><strong>No temp files</strong><br>The per-directory cache lives in tmux server options, nothing on disk.</td>
</tr>
<tr>
<td><strong>Per pane</strong><br>Each entry follows the active pane's path, so split panes track different repositories.</td>
<td><strong>Tested</strong><br>95%+ line coverage enforced in CI.</td>
</tr>
</table>

## Placeholders

Add either of these to `status-left` or `status-right`:

| Placeholder | Output |
|-------------|--------|
| `#{git}` | the full status, for example `main ~ 2 + 7 - 1 ? 3` |
| `#{git_branch}` | the current branch only |

Both resolve against the active pane's path and render nothing outside a repository.

## Install

With [TPM](https://github.com/tmux-plugins/tpm), add to `~/.tmux.conf`:

```tmux
set -g @plugin 'gufranco/tmux-git-revamped'
set -g status-right '#{git}'
```

Then press `prefix + I` to install.

Manual install:

```bash
git clone https://github.com/gufranco/tmux-git-revamped ~/.tmux/plugins/tmux-git-revamped
run-shell ~/.tmux/plugins/tmux-git-revamped/git-revamped.tmux
```

## Configuration

Each segment has a `_color` and an `_icon` option, so the icons below are defaults
you can replace with Nerd Font glyphs.

| Option | Default | Meaning |
|--------|---------|---------|
| `@git_revamped_interval` | `5` | seconds a cached status stays fresh |
| `@git_revamped_max_branch` | `25` | branch length before it is shortened |
| `@git_revamped_untracked` | `1` | set to `0` to hide the untracked count |
| `@git_revamped_stash` | `0` | set to `1` to show the stash count |
| `@git_revamped_ahead_behind` | `0` | set to `1` to show commits ahead and behind |
| `@git_revamped_last_commit` | `0` | set to `1` to show the last-commit age |
| `@git_revamped_web` | `0` | set to `1` to show provider PR, review, and issue counts |
| `@git_revamped_branch_{color,icon}` | empty | branch styling |
| `@git_revamped_changed_{color,icon}` | yellow, `~` | modified-file styling |
| `@git_revamped_insertions_{color,icon}` | green, `+` | inserted-lines styling |
| `@git_revamped_deletions_{color,icon}` | red, `-` | deleted-lines styling |
| `@git_revamped_untracked_{color,icon}` | blue, `?` | untracked-file styling |
| `@git_revamped_stash_{color,icon}` | magenta, `$` | stash styling |
| `@git_revamped_ahead_{color,icon}` | green, `^` | ahead styling |
| `@git_revamped_behind_{color,icon}` | yellow, `v` | behind styling |
| `@git_revamped_commit_{color,icon}` | blue, `@` | last-commit styling |
| `@git_revamped_{pr,review,issue}_{color,icon}` | see defaults | provider segment styling |

> [!IMPORTANT]
> The `@git_revamped_web` segment calls the GitHub or GitLab API on every refresh
> and needs `gh` plus `jq`, or `glab`, installed and authenticated. It is off by
> default. Leave it off unless you accept the API calls and their rate limits.

## Support by platform and architecture

Works on every supported platform and architecture with built-in tools. The status
reads through `git`, which is required, on Linux (x86_64 and arm64) and macOS
(Intel and Apple Silicon). The optional provider segment additionally needs `gh`
and `jq` for GitHub, or `glab` for GitLab; without them that segment stays empty.

## Development

```bash
make test    # bats suite
make lint    # shellcheck
make coverage  # kcov line coverage on Linux
```

## License

[MIT](LICENSE), copyright Gustavo Franco.
