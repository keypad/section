import SwiftUI

struct ThumbnailView: View {
	let item: WindowItem
	let selected: Bool

	private let accent = Color(red: 0.832, green: 0.69, blue: 0.549)
	private let radius: CGFloat = 10

	var body: some View {
		ZStack(alignment: .bottom) {
			Color.white.opacity(0.05)

			if let thumbnail = item.thumbnail {
				Image(nsImage: thumbnail)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: 200, height: 160)
					.clipped()
			} else if let icon = item.icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: 40, height: 40)
					.opacity(0.5)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}

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
			.frame(height: 30)
			.background(.ultraThinMaterial.opacity(0.9))
		}
		.frame(width: 200, height: 160)
		.clipped()
		.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: radius, style: .continuous)
				.strokeBorder(
					selected ? accent : .white.opacity(0.08),
					lineWidth: selected ? 2 : 1
				)
		)
		.shadow(color: selected ? accent.opacity(0.3) : .clear, radius: 12)
		.animation(.easeInOut(duration: 0.1), value: selected)
	}
}
