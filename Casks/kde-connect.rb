cask "kde-connect" do
  version "6981"
  sha256 "73c324327d1fbc4a04f1bc6c4c36e486880856674db8130e6cec672387ba5f1b"

  url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/release-26.12/macos-x86_64/kdeconnect-kde-release_26.12-#{version}-macos-clang-x86_64.dmg"
  name "KDE Connect"
  desc "CI build of the multi-platform device integration app"
  homepage "https://kdeconnect.kde.org/"

  livecheck do
    url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/release-26.12/macos-x86_64/"
    regex(/href=.*?kdeconnect-kde-release_26\.12-(\d+)-macos-clang-x86_64\.dmg/i)
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
