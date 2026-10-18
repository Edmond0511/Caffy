cask "caffy" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/Edmond0511/Caffy/releases/download/v#{version}/Caffy-#{version}.zip"
  name "Caffy"
  desc "Menu bar app to keep the computer awake using caffeinate"
  homepage "https://github.com/Edmond0511/Caffy"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "Caffy.app"

  # Quitting makes Caffy reset pmset disablesleep. The sudoers rule is left for zap,
  # since uninstall also runs on every upgrade.
  uninstall quit: "com.edmondyang.caffy"

  zap delete: "/etc/sudoers.d/caffy",
      trash:  "~/Library/Preferences/com.edmondyang.caffy.plist"

  caveats <<~EOS
    To also remove the lid-closed permission, uninstall with:
      brew uninstall --zap caffy
  EOS
end
