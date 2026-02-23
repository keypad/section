import SwiftUI

enum Accent: Int {
	case warm
	case light
	case catppuccin
	case nord
	case tokyonight
	case gruvbox
	case solarized

	var color: Color {
		switch self {
		case .warm:
			return Color(hex: 0xD4B08C)
		case .light:
			return Color(hex: 0x4C84E8)
		case .catppuccin:
			return Color(hex: 0xCBA6F7)
		case .nord:
			return Color(hex: 0x88C0D0)
		case .tokyonight:
			return Color(hex: 0x7AA2F7)
		case .gruvbox:
			return Color(hex: 0xFABD2F)
		case .solarized:
			return Color(hex: 0x268BD2)
		}
	}

	var card: Color {
		switch self {
		case .warm:
			return Color(hex: 0x0F1218)
		case .light:
			return Color(hex: 0xF3F6FB)
		case .catppuccin:
			return Color(hex: 0x313244)
		case .nord:
			return Color(hex: 0x3B4252)
		case .tokyonight:
			return Color(hex: 0x24283B)
		case .gruvbox:
			return Color(hex: 0x3C3836)
		case .solarized:
			return Color(hex: 0x073642)
		}
	}

	var bar: Color {
		switch self {
		case .warm:
			return Color(hex: 0x090B10)
		case .light:
			return Color(hex: 0xE8EEF7)
		case .catppuccin:
			return Color(hex: 0x45475A)
		case .nord:
			return Color(hex: 0x434C5E)
		case .tokyonight:
			return Color(hex: 0x292E42)
		case .gruvbox:
			return Color(hex: 0x504945)
		case .solarized:
			return Color(hex: 0x586E75)
		}
	}

	var text: Color {
		switch self {
		case .warm:
			return Color.white.opacity(0.9)
		case .light:
			return Color(hex: 0x1E2633)
		case .catppuccin:
			return Color(hex: 0xCDD6F4)
		case .nord:
			return Color(hex: 0xECEFF4)
		case .tokyonight:
			return Color(hex: 0xC0CAF5)
		case .gruvbox:
			return Color(hex: 0xEBDBB2)
		case .solarized:
			return Color(hex: 0x93A1A1)
		}
	}
}

extension Color {
	init(hex: UInt32) {
		let red = Double((hex >> 16) & 0xff) / 255
		let green = Double((hex >> 8) & 0xff) / 255
		let blue = Double(hex & 0xff) / 255
		self.init(red: red, green: green, blue: blue)
	}
}
