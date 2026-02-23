import AppKit
import ScreenCaptureKit

enum Capture {
	private actor Vault {
		var cache: [CGWindowID: NSImage] = [:]
		var order: [CGWindowID] = []
		let limit = 80

		func ready(ids: Set<CGWindowID>) -> [CGWindowID: NSImage] {
			var result: [CGWindowID: NSImage] = [:]
			for id in ids {
				if let image = cache[id] { result[id] = image }
			}
			return result
		}

		func seen(_ id: CGWindowID) -> Bool {
			cache[id] != nil
		}

		func store(id: CGWindowID, image: NSImage) {
			cache[id] = image
			order.removeAll { $0 == id }
			order.append(id)
			if order.count <= limit { return }
			let drop = order.count - limit
			for _ in 0..<drop {
				let old = order.removeFirst()
				cache.removeValue(forKey: old)
			}
		}
	}

	private static let vault = Vault()

	static func thumbnails(for items: [WindowItem], focus: Int, completion: @escaping @MainActor @Sendable ([CGWindowID: NSImage]) -> Void) {
		let lookup = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
		let priority = rank(items, focus: focus)
		Task {
			let cached = await vault.ready(ids: Set(priority))
			if !cached.isEmpty {
				await MainActor.run { completion(cached) }
			}

			let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
			guard let windows = content?.windows else { return }
			let table = Dictionary(uniqueKeysWithValues: windows.map { ($0.windowID, $0) })

			for (index, id) in priority.enumerated() {
				guard let window = table[id] else { continue }
				guard let item = lookup[id] else { continue }
				let urgent = index < 3
				let seen = await vault.seen(id)
				if seen && !urgent { continue }

				let filter = SCContentFilter(desktopIndependentWindow: window)
				let config = SCStreamConfiguration()

				let max: CGFloat = 560
				let w = item.bounds.width
				let h = item.bounds.height
				let fit = min(max / w, max / h, 1)

				config.width = Int(w * fit * 2)
				config.height = Int(h * fit * 2)
				config.scalesToFit = false
				config.preservesAspectRatio = true
				config.showsCursor = false
				config.ignoreShadowsSingleWindow = true
				config.shouldBeOpaque = true

				if let image = try? await SCScreenshotManager.captureImage(
					contentFilter: filter,
					configuration: config
				), let output = output(image) {
					let result = NSImage(cgImage: output, size: NSSize(width: 200, height: 160))
					await vault.store(id: id, image: result)
					await MainActor.run { completion([id: result]) }
				}
			}
		}
	}

	private static func rank(_ items: [WindowItem], focus: Int) -> [CGWindowID] {
		guard !items.isEmpty else { return [] }
		var list: [CGWindowID] = []
		let start = max(min(focus, items.count - 1), 0)
		list.append(items[start].id)
		for step in 1..<items.count {
			let right = start + step
			if right < items.count { list.append(items[right].id) }
			let left = start - step
			if left >= 0 { list.append(items[left].id) }
		}
		return list
	}

	private static func output(_ image: CGImage) -> CGImage? {
		guard let first = trim(image) else { return nil }
		return scale(first, maxw: 400, maxh: 320)
	}

	private static func trim(_ image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height
		let right = min(max(width / 60, 6), 14)
		guard width > right, height > 0 else { return image }
		let rect = CGRect(x: 0, y: 0, width: width - right, height: height)
		return image.cropping(to: rect) ?? image
	}

	private static func scale(_ image: CGImage, maxw: Int, maxh: Int) -> CGImage? {
		let width = image.width
		let height = image.height
		let fit = min(CGFloat(maxw) / CGFloat(width), CGFloat(maxh) / CGFloat(height), 1)
		let outw = max(Int(CGFloat(width) * fit), 1)
		let outh = max(Int(CGFloat(height) * fit), 1)

		let color = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil,
			width: outw,
			height: outh,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: color,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else { return nil }

		context.interpolationQuality = .high
		context.setFillColor(CGColor(gray: 0.06, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: outw, height: outh))
		context.draw(image, in: CGRect(x: 0, y: 0, width: outw, height: outh))
		return context.makeImage()
	}
}
