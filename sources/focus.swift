import AppKit

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

enum Focus {
	static func activate(_ item: WindowItem) {
		guard let app = NSRunningApplication(processIdentifier: item.pid) else { return }

		let appRef = AXUIElementCreateApplication(item.pid)
		var value: AnyObject?
		AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute as CFString, &value)

		if let windows = value as? [AXUIElement] {
			for window in windows {
				var windowID: CGWindowID = 0
				_ = _AXUIElementGetWindow(window, &windowID)
				if windowID == item.id {
					AXUIElementPerformAction(window, kAXRaiseAction as CFString)
					break
				}
			}
		}

		app.activate()
	}
}
