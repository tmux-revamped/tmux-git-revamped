# tmux-git-revamped

Guidance for anyone, human or agent, changing tmux-git-revamped. What it is and how to use it lives in [README.md](README.md).

[FAMILY.md](FAMILY.md) holds everything this plugin shares with the rest of the tmux-revamped family, and it is the same in every member. This file holds only what is exclusive to tmux-git-revamped, under the same headings as the agent guide of every member. Read both before changing anything; a rule that would serve the other members goes into [`FAMILY.md`](FAMILY.md) instead of here.

## Layout

| Path | Holds |
|:-----|:------|
| [`git-revamped.tmux`](git-revamped.tmux) | The entry point TPM runs |
| [`src/git.sh`](src/git.sh) | The script the placeholders, keys and popups call |
| [`src/lib/git/`](src/lib/git) | This member's modules |
| [`src/lib/utils/constants.sh`](src/lib/utils/constants.sh) | This member's constants, including its version |
| [`src/lib/utils/`](src/lib/utils), [`src/lib/tmux/`](src/lib/tmux) | The shared library. Every file there except `constants.sh` is identical in every member |
| [`test/`](test) | The bats suite. `helpers.bash` and `tmux_helpers.bash` are identical in every member; this member's own mocks go in the `_local` files. [`test/entry/keys.bats`](test/entry/keys.bats) presses the three keys through a second tmux attached to a private server, in a repository it creates, with stand-ins for `gh` and `lazygit` |

## Names

- Settings are tmux options named `@git_revamped_<setting>`.
- Placeholders include `#{git_branch}`.
- Public functions carry `git_`; private ones start with `_`.
- The version constant is `GIT_REVAMPED_VERSION`.
- Its command-line tool, once it exists, is `git-revamped`.

## Behaviour

- Shows the active pane's git branch, changes and provider counts in the status line without blocking it.
- `M-v` opens the branch menu; lazygit and browse have opt-in keys. A key that cannot act says why in a tmux message and exits 0, so it never ends in silence or in tmux's raw error screen: outside a repository, with no branch, without `lazygit`, `gh` or `glab`, with a remote that is neither GitHub nor GitLab, or when the provider tool fails.
- By default a placeholder becomes a `#()` call with `#{q:pane_current_path}` that prints the cached value for that path at once; a value older than `@git_revamped_interval` starts a detached refresh.
- With `@git_revamped_render` set to `options`, one background process per server walks every pane and writes each pane's value as a pane option, so switching panes shows that pane's repository at once.

## Domain rules

- Branch, tag and upstream names have every `#` doubled before they reach the status line, so a name such as `fix/#(cmd)` shows literally.

## Release

- `GIT_REVAMPED_VERSION` in [`src/lib/utils/constants.sh`](src/lib/utils/constants.sh) holds the version. Nobody edits it by hand.
- After a green `Tests` run on `main`, [`release.yml`](.github/workflows/release.yml) runs semantic-release from [`.releaserc.json`](.releaserc.json): a `feat` or `fix` since the last tag publishes a release, [`set-version.sh`](.github/scripts/set-version.sh) stamps the constant, and the notes go into [`CHANGELOG.md`](CHANGELOG.md).

## Gaps against FAMILY.md

As of 2026-11-17:

- Every script is bash, under `#!/usr/bin/env bash`, not POSIX `sh`, so it is untested under `dash`, `zsh` and BusyBox `sh`.
- The code lives in [`src/`](src) and [`src/lib/`](src/lib); there is no `bin/git-revamped`, `lib/state.sh` or `lib/core.sh`.
- No `git-revamped` command with `help`, `version` and `doctor` in the family's form, no man page, no completions and no `manifest.json`.
- No gum interface: no `lib/ui.sh`, `lib/table.awk`, themes or `test/bin/gum`.
- No `screens/`: no VHS recording of each feature, no on-screen caption of the keys each recording presses, and no recordings in the README.
- The README sections are not the family's order of Quick start, Usage, topic sections, Portability, Development and License.
- Coverage is kcov with a 95 percent floor on Linux, not bashcov at 100 percent merged from macOS and Linux.
- CI tests GNU, BSD and uutils tools in `tests.yml`, but not the six toolsets through `.github/scripts/toolset.sh`, and no shell matrix under `sh`, `dash`, `bash` and `zsh`.
- No golden transcripts, `call.sh`, `run-matrix.sh` or `linux-container.sh`.
- [`release.yml`](.github/workflows/release.yml) follows `Tests` and has no `recover` job, and [`.releaserc.json`](.releaserc.json) and `set-version.sh` name `src/lib/utils/constants.sh`, so the three differ from the family's copies; there is no `ci-state.sh`, `recover.sh`, `bot-merge.yml` or Renovate.
- CI is `tests.yml` and `security.yml`, not `ci.yml`, and no job starts with `step-security/harden-runner`.
- No `.editorconfig`, `.yamllint.yml` or shfmt; the Makefile has `help`, `test`, `test-unit`, `coverage`, `lint` and `clean`, not the family's targets.
- `get_tmux_option` keeps a tmux option set to nothing as an empty value, where FAMILY.md has it mean the default; the ticker's own reader already takes the default.
