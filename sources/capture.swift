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

				let maxDim: CGFloat = 720
				let w = item.bounds.width
				let h = item.bounds.height
				let fit = min(maxDim / w, maxDim / h, 1)

				config.width = Int(w * fit * 2)
				config.height = Int(h * fit * 2)
				config.scalesToFit = false
				config.showsCursor = false
				config.ignoreShadowsSingleWindow = true

				if let image = try? await SCScreenshotManager.captureImage(
					contentFilter: filter,
					configuration: config
				), let output = output(image) {
					results[wid] = NSImage(cgImage: output, size: NSSize(width: 200, height: 160))
				}
			}

			let captured = results
			await MainActor.run { completion(captured) }
		}
	}

	private static func output(_ image: CGImage) -> CGImage? {
		let base = opaque(image) ?? image
		guard let first = trim(base) else { return nil }
		return scale(first, maxWidth: 400, maxHeight: 320)
	}

	private static func trim(_ image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height

		let left = 0
		let top = 0
		let bottom = 0
		let right = min(max(width / 60, 6), 14)

		guard width > left + right, height > top + bottom else { return image }

		let rect = CGRect(
			x: left,
			y: bottom,
			width: width - left - right,
			height: height - top - bottom
		)

		return image.cropping(to: rect) ?? image
	}

	private static func opaque(_ image: CGImage) -> CGImage? {
		guard let raw = image.dataProvider?.data else { return nil }
		guard let data = CFDataGetBytePtr(raw) else { return nil }

		let width = image.width
		let height = image.height
		let row = image.bytesPerRow
		let bytes = image.bitsPerPixel / 8
		guard bytes >= 4 else { return nil }

		let alpha: Int
		switch image.alphaInfo {
		case .premultipliedFirst, .first, .noneSkipFirst:
			alpha = 0
		case .premultipliedLast, .last, .noneSkipLast:
			alpha = bytes - 1
		default:
			return nil
		}

		let step = 2
		let mark: UInt8 = 2
		var left = width
		var right = -1
		var top = height
		var bottom = -1

		var y = 0
		while y < height {
			var x = 0
			while x < width {
				let index = y * row + x * bytes + alpha
				if data[index] > mark {
					if x < left { left = x }
					if x > right { right = x }
					if y < top { top = y }
					if y > bottom { bottom = y }
				}
				x += step
			}
			y += step
		}

		guard right >= left, bottom >= top else { return nil }
		let pad = 1
		let x = max(left - pad, 0)
		let y0 = max(top - pad, 0)
		let w = min(right - left + 1 + pad * 2, width - x)
		let h = min(bottom - top + 1 + pad * 2, height - y0)
		let rect = CGRect(x: x, y: y0, width: w, height: h)
		return image.cropping(to: rect) ?? image
	}

	private static func scale(_ image: CGImage, maxWidth: Int, maxHeight: Int) -> CGImage? {
		let width = image.width
		let height = image.height
		let fit = min(CGFloat(maxWidth) / CGFloat(width), CGFloat(maxHeight) / CGFloat(height), 1)
		let outWidth = max(Int(CGFloat(width) * fit), 1)
		let outHeight = max(Int(CGFloat(height) * fit), 1)

		let color = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil,
			width: outWidth,
			height: outHeight,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: color,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }

		context.interpolationQuality = .high
		context.setFillColor(CGColor(gray: 0.06, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
		context.draw(image, in: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
		return context.makeImage()
	}
}
