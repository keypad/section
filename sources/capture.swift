import AppKit
import ScreenCaptureKit

enum Capture {
	static func thumbnails(for items: [WindowItem], completion: @escaping @MainActor @Sendable ([CGWindowID: NSImage]) -> Void) {
		let ids = Set(items.map { $0.id })
		Task {
			var results: [CGWindowID: NSImage] = [:]

			let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
			guard let windows = content?.windows else {
				await MainActor.run { completion(results) }
				return
			}

			for window in windows {
				let wid = window.windowID
				guard ids.contains(wid) else { continue }

				let filter = SCContentFilter(desktopIndependentWindow: window)
				let config = SCStreamConfiguration()
				config.width = 640
				config.height = 400
				config.scalesToFit = true
				config.showsCursor = false

				if let image = try? await SCScreenshotManager.captureImage(
					contentFilter: filter,
					configuration: config
				) {
					let nsImage = NSImage(cgImage: image, size: NSSize(width: 320, height: 200))
					results[wid] = nsImage
				}
			}

			let captured = results
			await MainActor.run { completion(captured) }
		}
	}
}
