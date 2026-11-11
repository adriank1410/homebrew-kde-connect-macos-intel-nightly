#!/usr/bin/env zsh
set -euo pipefail

project_url="https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/"
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

# KDE builds macOS Intel images on master and on release branches. Build
# numbers come from one counter shared by all branches and platforms (6450 on
# release-26.04 on 2026-08-02, 6461 on master a day later), so the higher
# number is the newer build. Master stopped getting Intel builds after 6589 on
# 2026-09-12 while release-26.08 reached 6891, hence both are checked.
#
# Prints the newest Intel build number in one branch directory, or nothing
# when the branch has no macOS Intel directory (HTTP 404) or no image in it.
latest_build_in() {
  local branch_dir="$1"
  local file_token
  file_token="$(print -r -- "${branch_dir//-/_}" | sed 's/\./\\./g')"
  local listing_file="$work_dir/listing-${branch_dir}.html"
  local http_code
  http_code="$(
    curl -sSL --retry 3 --output "$listing_file" --write-out '%{http_code}' \
      "${project_url}${branch_dir}/macos-x86_64/"
  )"
  if [[ "$http_code" == 404 ]]; then
    return 0
  fi
  if [[ "$http_code" != 200 ]]; then
    print -u2 "Unexpected HTTP $http_code for ${project_url}${branch_dir}/macos-x86_64/"
    exit 69
  fi
  { grep -Eo "kdeconnect-kde-${file_token}-[0-9]+-macos-clang-x86_64\\.dmg" "$listing_file" || true; } |
    sed -E 's/.*-([0-9]+)-macos-clang-x86_64\.dmg/\1/' |
    sort -n |
    tail -1
}

project_file="$work_dir/project.html"
curl -fsSL --retry 3 --output "$project_file" "$project_url"

# Release branches, newest first: release-26.08 before release-26.04.
release_dirs=("${(@f)$(
  { grep -Eo 'href="release-[0-9]+\.[0-9]+/"' "$project_file" || true; } |
    sed -E 's/^href="(release-[0-9]+\.[0-9]+)\/"$/\1/' |
    sort -u |
    sort -t- -k2,2 -rn
)}")

channel_dir="master"
latest_build="$(latest_build_in master)"

# A new release branch can exist before its first Intel build, so take the
# newest release branch that has one.
for release_dir in "${release_dirs[@]}"; do
  [[ -n "$release_dir" ]] || continue
  release_build="$(latest_build_in "$release_dir")"
  if [[ -n "$release_build" ]]; then
    if [[ -z "$latest_build" || "$release_build" -gt "$latest_build" ]]; then
      channel_dir="$release_dir"
      latest_build="$release_build"
    fi
    break
  fi
done

if [[ -z "$latest_build" ]]; then
  print -u2 "Could not find a KDE Connect macOS Intel build under $project_url"
  exit 69
fi

base_url="${project_url}${channel_dir}/macos-x86_64/"
file_prefix="kdeconnect-kde-${channel_dir//-/_}"
# The same name with its dots escaped, for the cask's livecheck regex.
file_prefix_regex="$(print -r -- "$file_prefix" | sed 's/\./\\./g')"

current_build=""
if [[ -f "$cask_file" ]]; then
  current_build="$(
    sed -n -E 's/^[[:space:]]*version[[:space:]]+"([0-9]+)".*/\1/p' "$cask_file" |
      tail -1
  )"
fi

if [[ -n "$current_build" && "$latest_build" -le "$current_build" ]]; then
  print "KDE Connect macOS Intel build is already current in the cask."
  print "Current cask build: $current_build"
  print "Latest KDE build: $latest_build ($channel_dir)"
  exit 0
fi

artifact_name="${file_prefix}-${latest_build}-macos-clang-x86_64.dmg"
artifact_url="${base_url}${artifact_name}"
artifact_file="$work_dir/$artifact_name"

print "Found KDE Connect macOS Intel build $latest_build on $channel_dir"
if [[ -n "$current_build" ]]; then
  print "Current cask build is $current_build; validating newer build $latest_build"
else
  print "No existing cask build found; validating build $latest_build"
fi
curl -fL --retry 3 --output "$artifact_file" "$artifact_url"

# HTTP/1.1 sends "Content-Length", HTTP/2 sends "content-length". macOS awk has
# no IGNORECASE, so compare a lowercased field name. With redirects the header
# file holds one block per response. Only the last block describes the
# artifact, so the value is cleared at each status line: a redirect's length
# must not stand in when the final response has none.
headers_file="$work_dir/headers.txt"
curl -fsSIL --retry 3 --output "$headers_file" "$artifact_url"
expected_length="$(
  awk '/^HTTP\// { header_value = "" } tolower($1) == "content-length:" { gsub(/\r/, "", $2); header_value = $2 } END { print header_value }' "$headers_file"
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

  url "${base_url}${file_prefix}-#{version}-macos-clang-x86_64.dmg"
  name "KDE Connect"
  desc "CI build of the multi-platform device integration app"
  homepage "https://kdeconnect.kde.org/"

  livecheck do
    url "${base_url}"
    regex(/href=.*?${file_prefix_regex}-(\\d+)-macos-clang-x86_64\\.dmg/i)
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
    This cask tracks KDE's CI builds of KDE Connect for macOS Intel: the newest
    of the master nightly and the latest release branch. KDE labels these
    builds as untested.
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
