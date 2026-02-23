import SwiftUI

struct ThumbnailView: View {
	let item: WindowItem
	let selected: Bool

	private let accent = Color(red: 0.832, green: 0.69, blue: 0.549)
	private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
	private let width: CGFloat = 220
	private let height: CGFloat = 160
	private let bar: CGFloat = 28

	var body: some View {
		VStack(spacing: 0) {
			ZStack {
				if let thumbnail = item.thumbnail {
					Image(nsImage: thumbnail)
						.resizable()
						.scaledToFill()
						.blur(radius: 10)
						.opacity(0.35)
						.frame(width: width, height: height - bar)
						.clipped()
					Image(nsImage: thumbnail)
						.resizable()
						.scaledToFit()
						.frame(width: width, height: height - bar)
				} else {
					Color.black.opacity(0.3)
					Color.white.opacity(0.05)
					if let icon = item.icon {
						Image(nsImage: icon)
							.resizable()
							.frame(width: 40, height: 40)
							.opacity(0.5)
					}
				}
			}
			.frame(width: width, height: height - bar)

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
			.background(Color.black.opacity(0.68))
		}
		.frame(width: width, height: height)
		.compositingGroup()
		.clipShape(shape, style: FillStyle(antialiased: true))
		.overlay(
			shape.strokeBorder(
				selected ? accent : .white.opacity(0.08),
				lineWidth: selected ? 2 : 1
			)
		)
		.shadow(color: selected ? accent.opacity(0.3) : .clear, radius: 12)
		.animation(.easeInOut(duration: 0.1), value: selected)
	}
}
