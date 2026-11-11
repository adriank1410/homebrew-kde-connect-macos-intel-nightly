cask "kde-connect" do
  version "6891"
  sha256 "c96a4915fc0d51ee53bd11e8c900a6d94ed9aba404765a8006ce1e82ffe2c33d"

  url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/release-26.08/macos-x86_64/kdeconnect-kde-release_26.08-#{version}-macos-clang-x86_64.dmg"
  name "KDE Connect"
  desc "CI build of the multi-platform device integration app"
  homepage "https://kdeconnect.kde.org/"

  livecheck do
    url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/release-26.08/macos-x86_64/"
    regex(/href=.*?kdeconnect-kde-release_26\.08-(\d+)-macos-clang-x86_64\.dmg/i)
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
