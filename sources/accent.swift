import SwiftUI

enum Accent: Int {
	case warm
	case catppuccin
	case nord
	case tokyonight
	case gruvbox
	case solarized

	var color: Color {
		switch self {
		case .warm:
			return Color(red: 0.832, green: 0.69, blue: 0.549)
		case .catppuccin:
			return Color(red: 0.796, green: 0.651, blue: 0.969)
		case .nord:
			return Color(red: 0.533, green: 0.753, blue: 0.816)
		case .tokyonight:
			return Color(red: 0.478, green: 0.682, blue: 1.0)
		case .gruvbox:
			return Color(red: 0.984, green: 0.741, blue: 0.247)
		case .solarized:
			return Color(red: 0.149, green: 0.545, blue: 0.824)
		}
	}
}
