```bash
> what is this?

  per-monitor window switcher for macos.
  keyboard-first with clean previews and optional video mode.
  lightweight and simple to install.

> features?

  ✓ per-monitor window switching
  ✓ option+tab quickswitch + hold-to-open flow
  ✓ picture mode (default)
  ✓ video mode (menu toggle)
  ✓ adaptive preview sizing per window
  ✓ accessibility + screen capture integration
  ✓ zero external dependencies

> defaults?

  picture mode: on
  per monitor: on

> controls?

  option+tab          → quickswitch (tap)
  hold option+tab     → open switcher
  tab / shift+tab     → cycle
  option release      → confirm
  esc                 → cancel
  option+`            → toggle lock mode (testing)

> menu options?

  picture
  video
  per monitor
  launch at login
  quit

> stack?

  swift 6 · appkit · swiftui · screencapturekit

> permissions?

  accessibility (hotkeys + window focus)
  screen recording (previews)

> run?

  swift run
  ./watch.local

> quality tools?

  formatter: swift format (toolchain)
  linter: swiftlint
  format: swift format format -i -r sources Package.swift
  lint: swiftlint lint --strict --config .swiftlint.yml
  check: swiftlint lint --strict --config .swiftlint.yml && swift build
  install swiftlint: brew install swiftlint

> install?

  brew tap keypad/section
  brew install --cask keypad/section/section
  or
  ./scripts/install
  open dist/section-0.1.0.dmg
  drag Section.app to applications
  optional signing: SIGN_IDENTITY="developer id application: ..." ./scripts/install

> links?

  https://section.sh
  https://github.com/keypad/section
```
