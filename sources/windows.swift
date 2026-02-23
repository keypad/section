import AppKit

struct WindowItem: Identifiable, @unchecked Sendable {
	let id: CGWindowID
	let name: String
	let owner: String
	let pid: pid_t
	let bounds: CGRect
	var thumbnail: NSImage?

	var icon: NSImage? {
		NSRunningApplication(processIdentifier: pid)?.icon
	}
}

enum Windows {
	private static let excluded: Set<String> = [
		"WindowManager", "Control Centre", "Notification Centre",
		"Window Server", "Dock",
	]

	static func list(on screen: NSScreen?) -> [WindowItem] {
		guard let info = CGWindowListCopyWindowInfo(
			[.optionOnScreenOnly, .excludeDesktopElements],
			kCGNullWindowID
		) as? [[String: Any]] else { return [] }

		let frame = screen?.frame
		let selfPid = ProcessInfo.processInfo.processIdentifier
		var items: [WindowItem] = []
		var rects: [pid_t: [CGRect]] = [:]

		for entry in info {
			guard
				let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
				let alpha = entry[kCGWindowAlpha as String] as? Double, alpha > 0,
				let wid = entry[kCGWindowNumber as String] as? CGWindowID,
				let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
				pid != selfPid,
				let owner = entry[kCGWindowOwnerName as String] as? String,
				!excluded.contains(owner),
				let boundsRef = entry[kCGWindowBounds as String],
				let cgRect = CGRect(dictionaryRepresentation: boundsRef as! CFDictionary),
				cgRect.width > 50, cgRect.height > 50
			else { continue }

			let nsRect = Screens.convertFromCG(cgRect)
			let center = NSPoint(x: nsRect.midX, y: nsRect.midY)

			if let frame, !frame.contains(center) { continue }

			let raw = (entry[kCGWindowName as String] as? String)?
				.trimmingCharacters(in: .whitespacesAndNewlines)
			let titled = !(raw?.isEmpty ?? true)

			if !titled {
				let dominated = rects[pid, default: []].contains { existing in
					let overlap = existing.intersection(cgRect)
					guard !overlap.isNull else { return false }
					let area = overlap.width * overlap.height
					let smaller = min(
						existing.width * existing.height,
						cgRect.width * cgRect.height
					)
					return area > smaller * 0.85
				}
				if dominated { continue }
			}

			rects[pid, default: []].append(cgRect)
			let name = titled ? raw! : owner

			items.append(WindowItem(
				id: wid,
				name: name,
				owner: owner,
				pid: pid,
				bounds: cgRect
			))
		}

		return items
	}
}
