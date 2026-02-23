cask "section" do
  version "0.1.0"
  sha256 "919c2f7c8f217b88556d6b9fd4a7c3920ed01c95f71ef2ea31fcc9f05aa0e4ea"

  url "https://github.com/keypad/section/releases/download/v#{version}/section-#{version}.dmg"
  name "Section"
  desc "Per-monitor window switcher for macOS"
  homepage "https://section.sh"

  app "Section.app"
end
