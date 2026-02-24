cask "section" do
  version "0.1.0"
  sha256 "236b2a22e114140052733c0c7c4d75819e76e795831db49f733679565c6ee1a6"

  url "https://github.com/keypad/section/releases/download/v#{version}/section-#{version}.dmg"
  name "Section"
  desc "Per-monitor window switcher for macOS"
  homepage "https://section.sh"

  app "Section.app"
end
