import AppKit

enum Icon {
	static func image() -> NSImage {
		let size = NSSize(width: 18, height: 18)
		let image = NSImage(size: size)
		image.lockFocus()
		let color = NSColor.labelColor
		color.setFill()

		let back = NSBezierPath(roundedRect: NSRect(x: 2.2, y: 2.4, width: 10.4, height: 10.6), xRadius: 1.7, yRadius: 1.7)
		back.lineWidth = 1.5
		back.stroke()

		let front = NSBezierPath(roundedRect: NSRect(x: 5.8, y: 5.8, width: 10.2, height: 9.8), xRadius: 1.7, yRadius: 1.7)
		front.lineWidth = 1.5
		front.stroke()

		image.unlockFocus()
		image.isTemplate = true
		return image
	}
}
