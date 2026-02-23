import AppKit
import ScreenCaptureKit

enum Permissions {
	static func check() {
		let prompt = "AXTrustedCheckOptionPrompt" as CFString
		let options = [prompt: true] as CFDictionary
		_ = AXIsProcessTrustedWithOptions(options)
		CGRequestScreenCaptureAccess()
	}
}
