import SwiftUI

struct ThumbnailView: View {
	let item: WindowItem
	let selected: Bool
	private static var cache: [CGWindowID: Color] = [:]
	private static var order: [CGWindowID] = []
	private static let limit = 256

	private let accent = Color(red: 0.832, green: 0.69, blue: 0.549)
	private let shape = Rectangle()
	private let height: CGFloat = 160
	private let bar: CGFloat = 28
	private var width: CGFloat { Grid.width(item, height: height, bar: bar) }
	private var previewheight: CGFloat { height - bar }
	private var barcolor: Color {
		if let color = Self.cache[item.id] { return color }
		guard let thumbnail = item.thumbnail else { return Color.black }
		let color = Self.tone(thumbnail)
		Self.set(id: item.id, color: color)
		return color
	}

	var body: some View {
		VStack(spacing: 0) {
			ZStack {
				Color.black
				if let thumbnail = item.thumbnail {
					Image(nsImage: thumbnail)
						.resizable()
						.scaledToFill()
						.frame(width: width + 2, height: previewheight + 2)
						.clipped()
				} else {
					Color.white.opacity(0.05)
					if let icon = item.icon {
						Image(nsImage: icon)
							.resizable()
							.frame(width: 40, height: 40)
							.opacity(0.5)
					}
				}
			}
			.frame(width: width, height: previewheight)

			HStack(spacing: 6) {
				if let icon = item.icon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: 14, height: 14)
				}
				Text(item.name)
					.font(.system(size: 11, weight: .medium))
					.foregroundStyle(.white.opacity(0.9))
					.lineLimit(1)
					.truncationMode(.tail)
			}
			.padding(.horizontal, 10)
			.frame(maxWidth: .infinity, alignment: .leading)
			.frame(height: bar, alignment: .center)
			.background(barcolor.opacity(0.94))
		}
		.frame(width: width, height: height)
		.compositingGroup()
		.clipShape(shape)
		.overlay(
			shape.strokeBorder(
				selected ? accent : .white.opacity(0.08),
				lineWidth: selected ? 2 : 1
			)
		)
		.shadow(color: selected ? accent.opacity(0.3) : .clear, radius: 12)
		.animation(.easeInOut(duration: 0.1), value: selected)
	}

	private static func tone(_ image: NSImage) -> Color {
		guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
			return Color.black
		}
		guard let raw = cg.dataProvider?.data else { return Color.black }
		guard let data = CFDataGetBytePtr(raw) else { return Color.black }

		let width = cg.width
		let height = cg.height
		let row = cg.bytesPerRow
		let bytes = cg.bitsPerPixel / 8
		guard bytes >= 4 else { return Color.black }

		let alpha: Int
		let red: Int
		let green: Int
		let blue: Int
		switch cg.alphaInfo {
		case .premultipliedFirst, .first, .noneSkipFirst:
			alpha = 0
			red = 1
			green = 2
			blue = 3
		case .premultipliedLast, .last, .noneSkipLast:
			alpha = 3
			red = 0
			green = 1
			blue = 2
		default:
			return Color.black
		}

		let step = 8
		var totalr: Double = 0
		var totalg: Double = 0
		var totalb: Double = 0
		var count: Double = 0

		var y = 0
		while y < height {
			var x = 0
			while x < width {
				let index = y * row + x * bytes
				let a = Double(data[index + alpha]) / 255
				if a > 0.1 {
					totalr += Double(data[index + red]) / 255
					totalg += Double(data[index + green]) / 255
					totalb += Double(data[index + blue]) / 255
					count += 1
				}
				x += step
			}
			y += step
		}

		guard count > 0 else { return Color.black }
		var r = totalr / count
		var g = totalg / count
		var b = totalb / count
		let floor = 0.12
		let ceil = 0.55
		r = min(max(r * 0.8, floor), ceil)
		g = min(max(g * 0.8, floor), ceil)
		b = min(max(b * 0.8, floor), ceil)
		return Color(red: r, green: g, blue: b)
	}

	private static func set(id: CGWindowID, color: Color) {
		cache[id] = color
		order.removeAll { $0 == id }
		order.append(id)
		guard order.count > limit else { return }
		let drop = order.count - limit
		for _ in 0..<drop {
			let old = order.removeFirst()
			cache.removeValue(forKey: old)
		}
	}
}
