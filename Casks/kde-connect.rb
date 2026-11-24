cask "kde-connect" do
  version "7011"
  sha256 "5a652c575e4aefa7f5dcd7a33aa796187f13522e0b4e1646d9b8fb8af1a50633"

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
