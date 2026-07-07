#!/usr/bin/env zsh
set -euo pipefail

base_url="https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/master/macos-x86_64/"
tap_dir="${1:-}"

usage() {
  print -u2 "Usage: update-kde-connect-cask.zsh /absolute/path/to/homebrew-tap"
}

require_command() {
  local cmd_name="$1"
  if ! command -v "$cmd_name" >/dev/null 2>&1; then
    print -u2 "Missing required command: $cmd_name"
    exit 69
  fi
}

if [[ -z "$tap_dir" ]]; then
  usage
  exit 64
fi

case "$tap_dir" in
  /*) ;;
  *)
    print -u2 "Tap directory must be an absolute path: $tap_dir"
    exit 64
    ;;
esac

require_command curl
require_command awk
require_command cmp
require_command cp
require_command grep
require_command hdiutil
require_command lipo
require_command mktemp
require_command mkdir
require_command rm
require_command sed
require_command shasum
require_command sort
require_command stat
require_command tail

mkdir -p "$tap_dir/Casks"
cask_file="$tap_dir/Casks/kde-connect.rb"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kde-connect-nightly.XXXXXX")"
mount_dir=""

cleanup() {
  if [[ -n "${mount_dir:-}" && -d "$mount_dir" ]]; then
    hdiutil detach "$mount_dir" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$work_dir"
}
trap cleanup EXIT INT TERM

html_file="$work_dir/index.html"
curl -fsSL --retry 3 --output "$html_file" "$base_url"

latest_build="$(
  { grep -Eo 'kdeconnect-kde-master-[0-9]+-macos-clang-x86_64\.dmg' "$html_file" || true; } |
    sed -E 's/.*master-([0-9]+)-.*/\1/' |
    sort -n |
    tail -1
)"

if [[ -z "$latest_build" ]]; then
  print -u2 "Could not find a KDE Connect macOS Intel nightly build in $base_url"
  exit 69
fi

current_build=""
if [[ -f "$cask_file" ]]; then
  current_build="$(
    sed -n -E 's/^[[:space:]]*version[[:space:]]+"([0-9]+)".*/\1/p' "$cask_file" |
      tail -1
  )"
fi

if [[ -n "$current_build" && "$latest_build" -le "$current_build" ]]; then
  print "KDE Connect macOS Intel nightly is already current in the cask."
  print "Current cask build: $current_build"
  print "Latest KDE build: $latest_build"
  exit 0
fi

artifact_name="kdeconnect-kde-master-${latest_build}-macos-clang-x86_64.dmg"
artifact_url="${base_url}${artifact_name}"
artifact_file="$work_dir/$artifact_name"

print "Found KDE Connect macOS Intel nightly build $latest_build"
if [[ -n "$current_build" ]]; then
  print "Current cask build is $current_build; validating newer build $latest_build"
else
  print "No existing cask build found; validating build $latest_build"
fi
curl -fL --retry 3 --output "$artifact_file" "$artifact_url"

expected_length="$(
  curl -fsSI "$artifact_url" |
    awk 'BEGIN { IGNORECASE = 1 } /^content-length:/ { gsub(/\r/, "", $2); print $2; exit }'
)"
actual_length="$(stat -f "%z" "$artifact_file")"

if [[ -n "$expected_length" && "$expected_length" != "$actual_length" ]]; then
  print -u2 "Refusing to update cask: downloaded size $actual_length does not match HTTP Content-Length $expected_length"
  exit 65
fi

sha256_value="$(shasum -a 256 "$artifact_file" | awk '{ print $1 }')"

if ! hdiutil imageinfo "$artifact_file" >"$work_dir/imageinfo.out" 2>"$work_dir/imageinfo.err"; then
  print -u2 "Refusing to update cask: KDE artifact is not mountable by hdiutil."
  sed 's/^/hdiutil: /' "$work_dir/imageinfo.err" >&2
  print -u2 "Artifact URL: $artifact_url"
  print -u2 "SHA-256: $sha256_value"
  exit 65
fi

mount_dir="$work_dir/mount"
mkdir -p "$mount_dir"
hdiutil attach -readonly -nobrowse -mountpoint "$mount_dir" "$artifact_file" >/dev/null

binary_file="$mount_dir/KDE Connect.app/Contents/MacOS/kdeconnect-cli"
if [[ ! -x "$binary_file" ]]; then
  print -u2 "Refusing to update cask: expected binary is missing or not executable: $binary_file"
  exit 65
fi

binary_arches="$(lipo -archs "$binary_file" 2>/dev/null || true)"
if [[ " $binary_arches " != *" x86_64 "* ]]; then
  print -u2 "Refusing to update cask: expected x86_64 binary, got: ${binary_arches:-unknown}"
  exit 65
fi

hdiutil detach "$mount_dir" -quiet >/dev/null
mount_dir=""

tmp_cask="$work_dir/kde-connect.rb"

cat >"$tmp_cask" <<CASK
cask "kde-connect" do
  version "$latest_build"
  sha256 "$sha256_value"

  url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/master/macos-x86_64/kdeconnect-kde-master-#{version}-macos-clang-x86_64.dmg"
  name "KDE Connect"
  desc "Nightly build of the multi-platform device integration app"
  homepage "https://kdeconnect.kde.org/"

  livecheck do
    url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/master/macos-x86_64/"
    regex(/href=.*?kdeconnect-kde-master-(\\d+)-macos-clang-x86_64\\.dmg/i)
  end

  depends_on macos: :ventura, arch: :x86_64

  app "KDE Connect.app"
  binary "#{appdir}/KDE Connect.app/Contents/MacOS/kdeconnect-cli",
         target: "kdeconnect"

  uninstall quit: "org.kde.kdeconnect"

  zap trash: [
    "~/Library/Application Support/kdeconnect.app",
    "~/Library/Application Support/kpeoplevcard/kdeconnect*",
    "~/Library/Caches/kdeconnect*",
    "~/Library/Preferences/kdeconnect",
    "~/Library/Preferences/org.kde.kdeconnect.plist",
    "~/Library/Preferences/State/kdeconnect.appstaterc",
  ]

  caveats <<~EOS
    This cask tracks KDE Connect macOS Intel nightly builds. KDE labels these
    nightly builds as untested.
  EOS
end
CASK

if [[ -e "$cask_file" ]] && cmp -s "$tmp_cask" "$cask_file"; then
  print "Cask is already current: $cask_file"
else
  cp "$tmp_cask" "$cask_file"
  print "Updated cask: $cask_file"
fi

print "Build: $latest_build"
print "SHA-256: $sha256_value"
