cask "section" do
  version "0.1.0"
  sha256 "e1bf92b5a02d3927e5022af46e7987063199934c99946156eb6980eb83105522"

  url "https://github.com/keypad/section/releases/download/v#{version}/section-#{version}.dmg"
  name "Section"
  desc "Per-monitor window switcher for macOS"
  homepage "https://section.sh"

  app "Section.app"
end
