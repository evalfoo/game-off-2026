# Game Off 2026

A Game Off 2026 jam entry (theme: SHIFT) in Godot 4 and GDScript: holding Shift makes the player bigger, heavier and slower. It is pixel art at 320×180 with flat placeholder art in `art/`.

## Ideas and design

The game's ideas, art and text are the owner's. Contribute game ideas, mechanics, twists, titles or verdicts on fun only when the owner asks; from play, report what happens. [The design notes](docs/design.md) hold the owner's decisions in their wording: record new ones there as given.

## Before editing

- For simulation, UI or persistence changes, read the relevant code-map and convention sections in [implementation notes](docs/implementation.md). Engine and implementation decisions go there too.
- For setup, launch and test commands, use [the README](README.md). Keep machine-specific executable paths out of project files; they go in the git-ignored `mise.local.toml`.
- For code changes, apply the review rules in [the coding standards](CODING_STANDARDS.md) that fit the change. [The docs index](docs/README.md) lists the other docs.
- For engine or UI code that isn't specific to this game, check [evalfoo/godot-addons](https://github.com/evalfoo/godot-addons) first. To use one, unzip its release into `addons/<name>/` and list the addon and its release tag, such as `sylves/v0.3.0`, in the implementation notes. Addon bugs and improvements go upstream: suggest an issue on that repo to the owner.
- The files that `tools/update.sh` lists come from the template and get replaced on update. Fix them in the template: suggest an issue on evalfoo/godot-template to the owner. The game's part of the play driver lives in `game/play_hooks.gd`.

## Verification

Select checks from [the README's verification instructions](README.md#verify) according to the changed behavior:

- Simulation and rule changes need headless checks that cover the changed rules.
- UI, input, camera and visual changes need a native Godot window. Exercise the changed interaction and inspect its rendered result; headless checks do not establish visual correctness.
- To look at a change without writing a script, play it through the `game` MCP server; see [Let an agent play](README.md#let-an-agent-play). It doesn't replace scripted checks.
- Visible changes attach before/after evidence: stills from `tools/clips/stills.sh`, and clips from `tools/clips/record.sh` for motion (camera, easing, animation). AI reviewers get the frame strips.
- Persistence changes need save/restore checks that restore in a fresh process. Use isolated test saves rather than player data.

Run the full native suite once per PR, on the commit you send to review. For later review fixes, rerun only the native scripts that cover the changed code.

Before declaring completion, report which checks ran and their observed results. Distinguish seeded or staged fixtures, such as a save set up for the check, from ordinary play. Keep run results, timings and measurements out of the docs; the pull request names the checks that passed. State any unverified platform or interaction explicitly.

## Parallel and sandboxed agents

- In a Codex sandbox, `.codex/rules/project.rules` runs native Godot outside the sandbox, where the GPU is, but only in these exact shapes, each as a whole command: `mise run test:native`, `mise exec -- tests/run.sh tests/<x>_native.gd`, `mise exec -- tools/native.sh godot --path . ...`, and `tools/clips/record.sh ...` or `tools/clips/stills.sh ...` called bare. An env var, `export`, `source` or `cd` in front keeps the command in the sandbox, which has no GPU.
- Save screenshots, clips and logs under the git-ignored `tests/output/`.
- `.agents/worktree-setup` prepares a fresh worktree. Without an import, scripts fail with errors such as `Could not find base class`. Run `mise run import` again after a rebase or merge that adds classes.
