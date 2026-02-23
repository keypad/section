import SwiftUI

struct ThumbnailView: View {
	let item: WindowItem
	let selected: Bool
	let theme: Theme
	let accent: Accent

	private let shape = Rectangle()
	private let height: CGFloat = 160
	private let bar: CGFloat = 28
	private var width: CGFloat {
		if theme == .minimal { return 220 }
		return Grid.width(item, height: height, bar: bar)
	}
	private var previewheight: CGFloat { height - bar }

	var body: some View {
		if theme == .minimal {
			HStack(spacing: 8) {
				if let icon = item.icon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: 14, height: 14)
				}
				Text(item.name)
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(accent.text)
					.lineLimit(1)
					.truncationMode(.tail)
			}
			.padding(.horizontal, 10)
			.frame(width: width, height: 44, alignment: .leading)
			.background(accent.bar.opacity(0.92))
			.overlay(
				shape.strokeBorder(
					selected ? accent.color : .white.opacity(0.08),
					lineWidth: selected ? 2 : 1
				)
			)
		} else {
			VStack(spacing: 0) {
				ZStack {
					accent.card
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
						.foregroundStyle(accent.text)
						.lineLimit(1)
						.truncationMode(.tail)
				}
				.padding(.horizontal, 10)
				.frame(maxWidth: .infinity, alignment: .leading)
				.frame(height: bar, alignment: .center)
				.background(accent.bar.opacity(0.94))
			}
			.frame(width: width, height: height)
			.compositingGroup()
			.clipShape(shape)
			.overlay(
				shape.strokeBorder(
					selected ? accent.color : .white.opacity(0.08),
					lineWidth: selected ? 2 : 1
				)
			)
			.shadow(color: selected ? accent.color.opacity(0.12) : .clear, radius: 4)
		}
	}
}
