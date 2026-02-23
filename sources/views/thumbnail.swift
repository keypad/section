import SwiftUI

struct ThumbnailView: View {
	let item: WindowItem
	let selected: Bool

	private let accent = Color(red: 0.832, green: 0.69, blue: 0.549)

	var body: some View {
		VStack(spacing: 8) {
			ZStack {
				RoundedRectangle(cornerRadius: 8)
					.fill(.white.opacity(0.05))
					.frame(height: 112)

				if let thumbnail = item.thumbnail {
					Image(nsImage: thumbnail)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(height: 112)
						.clipShape(RoundedRectangle(cornerRadius: 6))
				} else if let icon = item.icon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: 48, height: 48)
						.opacity(0.6)
				}
			}

			HStack(spacing: 6) {
				if let icon = item.icon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: 16, height: 16)
				}

				Text(item.name)
					.font(.system(size: 11))
					.foregroundStyle(.white.opacity(0.7))
					.lineLimit(1)
					.truncationMode(.tail)
			}
		}
		.padding(8)
		.background(
			RoundedRectangle(cornerRadius: 10)
				.fill(selected ? accent.opacity(0.15) : .clear)
		)
		.overlay(
			RoundedRectangle(cornerRadius: 10)
				.strokeBorder(selected ? accent : .white.opacity(0.1), lineWidth: selected ? 2 : 1)
		)
		.shadow(color: selected ? accent.opacity(0.3) : .clear, radius: 12)
		.frame(width: 200, height: 160)
		.animation(.easeInOut(duration: 0.1), value: selected)
	}
}
