import ServiceManagement

enum Launch {
	static func available() -> Bool {
		if #available(macOS 13.0, *) { return true }
		return false
	}

	static func enabled() -> Bool {
		guard #available(macOS 13.0, *) else { return false }
		return SMAppService.mainApp.status == .enabled
	}

	static func set(_ enabled: Bool) -> Bool {
		guard #available(macOS 13.0, *) else { return false }
		do {
			if enabled {
				try SMAppService.mainApp.register()
			} else {
				try SMAppService.mainApp.unregister()
			}
			return true
		} catch {
			return false
		}
	}
}
