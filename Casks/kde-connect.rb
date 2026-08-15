cask "kde-connect" do
  version "6493"
  sha256 "829622d3e2af6321a9baa1efbb8a3355d5d65d3609318e0275f4cb75297480a9"

  url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/master/macos-x86_64/kdeconnect-kde-master-#{version}-macos-clang-x86_64.dmg"
  name "KDE Connect"
  desc "Nightly build of the multi-platform device integration app"
  homepage "https://kdeconnect.kde.org/"

  livecheck do
    url "https://origin.cdn.kde.org/ci-builds/network/kdeconnect-kde/master/macos-x86_64/"
    regex(/href=.*?kdeconnect-kde-master-(\d+)-macos-clang-x86_64\.dmg/i)
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
