# KDE Connect macOS Intel Nightly Homebrew Tap

Homebrew tap for the official KDE Connect macOS Intel CI builds.

The upstream Homebrew Cask currently packages the stable macOS build of KDE
Connect, which is ARM-only. KDE also publishes untested macOS Intel builds
from its CI, both from `master` (the nightly) and from release branches. This
tap exists to make the newest of those builds installable through a normal
Homebrew tap while keeping update checks conservative.

This project is not affiliated with KDE or Homebrew.

## Motivation

For macOS specifically, KDE Connect publishes:

- a stable macOS release for Apple Silicon,
- nightly macOS builds for Apple Silicon,
- macOS Intel CI builds from `master` and from release branches.

KDE Connect is also available on other platforms, including Windows, but this
tap only concerns the macOS Intel CI builds.

The stable Intel URL for the current KDE Connect macOS release does not exist,
so the official Homebrew Cask cannot safely add an Intel variant until KDE
publishes a stable Intel artifact. This tap tracks the CI builds instead.

## Which Build The Cask Follows

The cask follows whichever is newer: the `master` nightly or the build of the
newest release branch that has a macOS Intel image. KDE numbers builds with one
counter across branches and platforms, so the higher number is the newer build.
This is inferred from the published numbers (6450 on `release-26.04` on
2026-08-02, 6461 on `master` a day later); KDE does not document it.

Until 2026-09-12 that was always `master`. KDE has published no macOS Intel
build on `master` since build 6589 of that day, while `release-26.08` got build
6891 on 2026-11-02. If `master` builds resume, the cask goes back to them once
their number is higher. Older release branches are never used.

## Install

```bash
brew tap adriank1410/kde-connect-macos-intel-nightly
brew install --cask adriank1410/kde-connect-macos-intel-nightly/kde-connect
```

If your Homebrew configuration requires explicit tap trust:

```bash
brew trust --cask adriank1410/kde-connect-macos-intel-nightly/kde-connect
```

## Update

```bash
brew update
brew upgrade --cask adriank1410/kde-connect-macos-intel-nightly/kde-connect
```

If you keep the cask pinned locally, unpin before upgrading and pin it again
afterwards:

```bash
brew unpin kde-connect
brew upgrade --cask adriank1410/kde-connect-macos-intel-nightly/kde-connect
brew pin kde-connect
```

## How Updates Work

The GitHub Actions workflow is scheduled every 30 minutes on a macOS runner.
GitHub starts scheduled workflows on a best-effort basis and skips most of
these slots: from 2026-09-14 to 2026-11-10 this repository got about five runs
a day, one every 4.7 hours on average. Each run:

1. Reads the KDE Connect CI directories for `master` and the release branches.
2. Extracts the newest macOS Intel build number of `master` and of the newest
   release branch that has one, and takes the higher.
3. Compares that build number with `Casks/kde-connect.rb`.
4. Exits without downloading anything when the cask is already current.
5. Downloads the DMG only when KDE publishes a newer build.
6. Verifies the downloaded byte size and computes SHA-256.
7. Checks that `hdiutil` can read and mount the DMG.
8. Checks that `KDE Connect.app/Contents/MacOS/kdeconnect-cli` contains
   `x86_64`.
9. Regenerates the cask with the new version and SHA-256.
10. Runs `brew style`, `brew audit`, and `brew livecheck`.
11. Commits the cask update only after validation passes.

The workflow can also be started manually from GitHub Actions. Each KDE CI
directory retains only its current build, so frequent polling reduces
the window in which a cask can point at a retired artifact. GitHub Actions
scheduling and the upstream CDN are outside this tap's control, so a 404
remains possible after an upstream build transition until the next run commits
the new build.

## Why Not Only `livecheck`?

Homebrew `livecheck` can detect that a newer upstream build exists, but
`brew upgrade` does not rewrite cask files or compute new checksums. A cask
update still has to be committed to the tap first. This repository automates
that commit step.

## Public Tap Safety Notes

The repository is public so other Intel Mac users can use the macOS nightly tap without
personal access tokens.

The update workflow is intentionally narrow:

- it does not run on pull requests,
- it uses no repository secrets,
- it uses the default `GITHUB_TOKEN` only to commit validated cask updates,
- it writes only `Casks/kde-connect.rb`,
- it validates the macOS DMG on a macOS runner before committing.

Cloning or viewing this public repository does not expose the repository
owner's token. GitHub creates the workflow `GITHUB_TOKEN` only at run time, and
that token is scoped to this repository.

## Limitations

KDE labels its macOS CI builds as untested. This tap validates that the
published DMG is mountable and contains an Intel binary, but it cannot guarantee
runtime stability of KDE Connect itself.

When KDE publishes a stable Intel macOS build, the better long-term solution is
to update the official `homebrew/cask` `kde-connect` cask.
