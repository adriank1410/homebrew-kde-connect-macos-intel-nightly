# KDE Connect Intel Nightly Homebrew Tap

Homebrew tap for the official KDE Connect macOS Intel nightly builds.

The upstream Homebrew Cask currently packages the stable macOS build of KDE
Connect, which is ARM-only. KDE also publishes untested nightly builds for Intel
macOS. This tap exists to make those Intel nightly builds installable through a
normal Homebrew tap while keeping update checks conservative.

This project is not affiliated with KDE or Homebrew.

## Motivation

KDE Connect publishes:

- a stable macOS release for Apple Silicon,
- nightly macOS builds for Apple Silicon,
- nightly macOS builds for Intel.

The stable Intel URL for the current KDE Connect macOS release does not exist,
so the official Homebrew Cask cannot safely add an Intel variant until KDE
publishes a stable Intel artifact. This tap tracks the Intel nightly channel
instead.

## Install

```bash
brew tap adriank1410/kde-nightly
brew install --cask adriank1410/kde-nightly/kde-connect
```

If your Homebrew configuration requires explicit tap trust:

```bash
brew trust --cask adriank1410/kde-nightly/kde-connect
```

## Update

```bash
brew update
brew upgrade --cask adriank1410/kde-nightly/kde-connect
```

If you keep the cask pinned locally, unpin before upgrading and pin it again
afterwards:

```bash
brew unpin kde-connect
brew upgrade --cask adriank1410/kde-nightly/kde-connect
brew pin kde-connect
```

## How Updates Work

The scheduled GitHub Actions workflow runs on a macOS runner and:

1. Reads the KDE Connect Intel nightly directory.
2. Extracts the newest build number with a regex.
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

The workflow runs daily and can also be started manually from GitHub Actions.

## Why Not Only `livecheck`?

Homebrew `livecheck` can detect that a newer upstream build exists, but
`brew upgrade` does not rewrite cask files or compute new checksums. A cask
update still has to be committed to the tap first. This repository automates
that commit step.

## Public Tap Safety Notes

The repository is public so other Intel Mac users can use the tap without
personal access tokens.

The update workflow is intentionally narrow:

- it does not run on pull requests,
- it uses no repository secrets,
- it uses the default `GITHUB_TOKEN` only to commit validated cask updates,
- it writes only `Casks/kde-connect.rb`,
- it validates the macOS DMG on a macOS runner before committing.

## Limitations

KDE labels the nightly builds as untested. This tap validates that the published
DMG is mountable and contains an Intel binary, but it cannot guarantee runtime
stability of KDE Connect itself.

When KDE publishes a stable Intel macOS build, the better long-term solution is
to update the official `homebrew/cask` `kde-connect` cask.
