---
name: release-notes
description: Publish a GitHub release with devlog-style notes for a version tag, or rewrite an existing release's notes. Use when asked to create, add or write up a release.
argument-hint: <version, e.g. 0.5.0>
---

# Release notes

The Release workflow (`.github/workflows/release.yml`) builds, uploads to itch.io and pushes the `vX.Y.Z` tag. It makes no GitHub release. This skill writes one: a short devlog for players and testers, not a changelog.

## 1. Find the range

- `git fetch --tags origin`, then `git tag -l --sort=creatordate` and `gh release list`.
- The range is the previous tag to the requested tag.
- If the tag doesn't exist, check `gh run list --workflow release.yml` and report what you see. The workflow owns tags, so leave tagging to it.
- If the release already exists, this is a rewrite: you'll finish with `gh release edit` instead of `create`.

Done when you know both tags and whether the release exists.

## 2. Read what changed

- `git log --reverse --format='%as %s' <prev>..<tag>`, and the commit count.
- Read the body of every `feat` and `fix` PR (`gh pr view <n> --json title,body`). The bodies give the problem each change solved, which is what the notes tell. Skim `refactor`, `perf` and tool PRs only to sum them up.
- Grep those bodies for save changes. Note whether saves from the previous release still load.
- Get the itch.io page from `gh variable get ITCH_TARGET` (`user/game` gives `https://user.itch.io/game`).
- Get the platforms from the `butler" push` lines in `git show <tag>:.github/workflows/release.yml` (channels `windows`, `linux`, `mac`). If the list differs from the previous tag's, that's news for the notes, such as "the first release with a macOS build".

Done when every player-visible change sits under a theme, and you know the save answer and the platforms.

## 3. Write the notes

Write to `tests/output/release-notes/<tag>.md`. Follow the published releases (`gh release view <prev>`) for tone:

- Open with one or two sentences: how long the release took, the commit count and its main theme.
- `##` sections by player-visible theme, the biggest first. Each says what used to happen, then what happens now, in plain player words.
- End each claim with its PR numbers, like `(#12)` or `(#14 to #16)`.
- Later sections, in order and only when they apply: smaller fixes as a list, "Under the hood" for refactors and tools in a few sentences, and a saves note (old saves won't load and why, or old saves load fine).
- Last two lines: `<Platforms> builds are on [itch.io](<itch url>).` (for example "Windows, Linux and macOS") and `Full list of changes: <repo>/compare/<prev>...<tag>`.

If an `unslop` skill is available, run it over the draft. Then check for em dashes, en dashes and curly quotes with `grep -nP '—|–|[“”‘’]'`. Done when every sentence traces to a commit or a PR body.

## 4. Publish

- New: `gh release create <tag> --verify-tag --title <tag> --notes-file <file> --latest`
- Rewrite: `gh release edit <tag> --notes-file <file>`

Report the release URL, a one-line summary of each section, and any claim you took from a PR body without checking it yourself, such as save compatibility.
