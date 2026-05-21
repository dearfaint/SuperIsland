cask "superisland" do
  version "1.0.8"

  on_arm do
    sha256 "REPLACE_WITH_ARM64_DMG_SHA256"
    url "https://github.com/shobhit99/superisland/releases/download/v#{version}/SuperIsland.dmg"
  end

  on_intel do
    sha256 "REPLACE_WITH_X86_64_DMG_SHA256"
    url "https://github.com/shobhit99/superisland/releases/download/v#{version}/SuperIsland-x86_64.dmg"
  end

  name "SuperIsland"
  desc "Interactive island for the Mac notch"
  homepage "https://dynamicisland.app/"

  depends_on macos: ">= :sonoma"

  app "SuperIsland.app"

  zap trash: [
    "~/Library/Application Support/SuperIsland",
    "~/Library/Caches/com.workview.SuperIsland",
    "~/Library/Preferences/com.workview.SuperIsland.plist",
  ]
end
