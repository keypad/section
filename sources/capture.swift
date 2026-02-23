import AppKit
import ScreenCaptureKit

enum Capture {
	static func thumbnails(for items: [WindowItem], completion: @escaping @MainActor @Sendable ([CGWindowID: NSImage]) -> Void) {
		let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
		let aspect: CGFloat = 200 / 160
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
				let maxDim: CGFloat = 640
				let w = item.bounds.width
				let h = item.bounds.height
				let scaleRatio = min(maxDim / w, maxDim / h, 1)

				config.width = Int(w * scaleRatio * scale)
				config.height = Int(h * scaleRatio * scale)
				config.scalesToFit = false
				config.showsCursor = false
				config.ignoreShadowsSingleWindow = true

				if let image = try? await SCScreenshotManager.captureImage(
					contentFilter: filter,
					configuration: config
				) {
					let source = crop(image, ratio: aspect)
					let size = NSSize(
						width: CGFloat(source.width) / scale,
						height: CGFloat(source.height) / scale
					)
					results[wid] = NSImage(cgImage: source, size: size)
				}
			}

			let captured = results
			await MainActor.run { completion(captured) }
		}
	}

	private static func crop(_ image: CGImage, ratio: CGFloat) -> CGImage {
		let width = image.width
		let height = image.height

		let left = min(max(width / 180, 2), 8)
		let top = min(max(height / 180, 2), 8)
		let bottom = top
		let right = min(max(width / 30, 8), 24)

		guard width > left + right, height > top + bottom else { return image }

		let outer = CGRect(
			x: left,
			y: bottom,
			width: width - left - right,
			height: height - top - bottom
		)

		guard let first = image.cropping(to: outer) else { return image }
		let inner = fit(first, ratio: ratio)
		return first.cropping(to: inner) ?? first
	}

	private static func fit(_ image: CGImage, ratio: CGFloat) -> CGRect {
		let width = CGFloat(image.width)
		let height = CGFloat(image.height)
		let current = width / height

		if current > ratio {
			let target = floor(height * ratio)
			let inset = floor((width - target) / 2)
			return CGRect(x: inset, y: 0, width: target, height: height)
		}

		if current < ratio {
			let target = floor(width / ratio)
			let inset = floor((height - target) / 2)
			return CGRect(x: 0, y: inset, width: width, height: target)
		}

		return CGRect(x: 0, y: 0, width: width, height: height)
	}
}
