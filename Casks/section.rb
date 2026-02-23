cask "section" do
  version "0.1.0"
  sha256 "def032512d974c51dbe751d8b65a2b6347f1c036d8b290841c0355023b1db737"

  url "https://github.com/keypad/section/releases/download/v#{version}/section-#{version}.dmg"
  name "Section"
  desc "Per-monitor window switcher for macOS"
  homepage "https://section.sh"

  app "Section.app"
end
