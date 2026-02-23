import AppKit
import ScreenCaptureKit

enum Capture {
	static func thumbnails(for items: [WindowItem], completion: @escaping @MainActor @Sendable ([CGWindowID: NSImage]) -> Void) {
		let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
		Task {
			var results: [CGWindowID: NSImage] = [:]

			let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
			guard let windows = content?.windows else {
				await MainActor.run { completion(results) }
				return
			}

			for window in windows {
				let wid = window.windowID
				guard let item = lookup[wid] else { continue }

				let filter = SCContentFilter(desktopIndependentWindow: window)
				let config = SCStreamConfiguration()

				let scale: CGFloat = 2
				let maxDim: CGFloat = 400
				let w = item.bounds.width
				let h = item.bounds.height
				let ratio = min(maxDim / w, maxDim / h, 1)

				config.width = Int(w * ratio * scale)
				config.height = Int(h * ratio * scale)
				config.scalesToFit = false
				config.showsCursor = false

				if let image = try? await SCScreenshotManager.captureImage(
					contentFilter: filter,
					configuration: config
				) {
					let source = crop(image)
					let size = NSSize(
						width: CGFloat(config.width) / scale,
						height: CGFloat(config.height) / scale
					)
					results[wid] = NSImage(cgImage: source, size: size)
				}
			}

			let captured = results
			await MainActor.run { completion(captured) }
		}
	}

	private static func crop(_ image: CGImage) -> CGImage {
		let inset = 4
		let width = image.width
		let height = image.height
		guard width > inset * 2, height > inset * 2 else { return image }
		let rect = CGRect(
			x: inset,
			y: inset,
			width: width - inset * 2,
			height: height - inset * 2
		)
		return image.cropping(to: rect) ?? image
	}
}
