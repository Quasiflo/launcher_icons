# Contributing

Thanks for helping out! This repo is intentionally easy to work in: plain Dart, no build system beyond `pub`, one test command.

> Note, this repo is currently developed on MacOS, if you have trouble setting up this repo for development on Linux or Windows, it might be a bug or misconfiguration! Feel free to reach out!

## Setup

1. Install [mise](https://mise.jdx.dev/getting-started.html), then run the following command to fetch the pinned tools from the repo root (hk, rumdl, zizmor — see [.config/mise.toml](.config/mise.toml)):

   ```shell
   mise install
   ```

2. You also need a Dart SDK, and if you're building the examples, possibly android sdk, linux build tools, cocoapods for MacOS etc. Most developers already have these installed, but if you prefer to go the full Mise install path, you can do so by:

   ```shell
   echo "env = [\"toolchain\"]" > .config/miserc.toml
   mise install
   ```

   This configures mise to use the "toolchain" environment, which includes the extra dependencies from [.config/mise.toolchain.toml](.config/mise.toolchain.toml)
3. Install the git hooks — recommended once per machine (Git 2.54+, silent no-op in repos without hk config):

   ```shell
   hk install --global
   ```

   Or repo-only with `hk install`. Skip hooks for one command with `HK=0`. Optional global defaults (extra steps, `jobs`, …) live in `~/.config/hk/config.pkl`. More in the [hk docs](https://hk.jdx.dev/getting-started.html).
4. Get dependencies and confirm green:

   ```shell
   dart pub get
   hk check --all
   ```

## Workflow

- `hk check --all` verifies everything (format, lints, analyzer, markdown, workflows). It doesn't modify files. `hk fix --all` on the other hand applies what it can — formatting, fixes, and codegen.
- New config key? Add it to the `:generate` template in `bin/generate.dart` (there is a drift test), document it in `README.md`, and cover it with a test. Behavior changes to an existing platform should also refresh the [flavors example](example/flavors) outputs (`dart run launcher_icons` in `example/flavors`).
- `dart test` to run the full test suite
- Fixture artwork (`test/assets`, `example/default/assets/images`, etc.) is derived from checked-in SVG masters: edit the SVG, then `dart run tool/render_fixtures.dart` (or `--check` to verify the pixel contracts without writing). The renderer gates on the properties the suite asserts (alpha, ring/teal pixels), so run it before committing art changes.
- `lib/src/version.dart` is bumped by Release-Please, no need to hand edit.
- Keep it simple: small focused diffs, one concern per commit.

## Commits and Releases

Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:` / `fix:` release a new version, `docs:` / `refactor:` / `chore:` / `test:` / `style:` don't. [release-please](https://github.com/googleapis/release-please) bumps the version and writes [CHANGELOG.md](CHANGELOG.md) from commit messages — never edit either by hand, and keep the `x-release-please-version` markers in `pubspec.yaml`, `README.md`, and `lib/src/version.dart`.

CI runs the analyzer and the full test suite on every pull request.
