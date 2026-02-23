// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "section",
	platforms: [.macOS(.v14)],
	targets: [
		.executableTarget(
			name: "section",
			path: "sources",
			exclude: ["info.plist"],
			linkerSettings: [
				.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "sources/info.plist"])
			]
		)
	]
)
