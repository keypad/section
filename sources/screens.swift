import AppKit

enum Screens {
	static func current() -> NSScreen {
		let location = NSEvent.mouseLocation
		return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
			?? NSScreen.main
			?? NSScreen.screens[0]
	}

	static func convertFromCG(_ rect: CGRect) -> NSRect {
		guard let primary = NSScreen.screens.first else { return rect }
		let y = primary.frame.height - rect.origin.y - rect.height
		return NSRect(x: rect.origin.x, y: y, width: rect.width, height: rect.height)
	}
}
