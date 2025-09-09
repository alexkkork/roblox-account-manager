import Foundation
import Darwin

func run() {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        print("usage: robloxmulti <roblox-player-url>")
        exit(2)
    }
    let url = args[1]

    // Resolve Roblox.app
    let baseCandidates = ["/Applications/Roblox.app", NSHomeDirectory() + "/Applications/Roblox.app"]
    let appURL: URL? = baseCandidates.compactMap { path in
        FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }.first
    guard let source = appURL else { print("Roblox.app not found"); exit(1) }

    // Clone
    let clonesRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Application Support/RobloxAccountManager/Clones", isDirectory: true)
    try? FileManager.default.createDirectory(at: clonesRoot, withIntermediateDirectories: true)
    let container = clonesRoot.appendingPathComponent(String(UUID().uuidString.prefix(8)), isDirectory: true)
    try? FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    let targetApp = container.appendingPathComponent("Roblox.app")

    let cp = Process()
    cp.executableURL = URL(fileURLWithPath: "/bin/cp")
    cp.arguments = ["-a", source.path, container.path]
    try? cp.run(); cp.waitUntilExit()

    // Allow multi-instances on the clone
    let infoPlist = targetApp.appendingPathComponent("Contents/Info.plist")
    if let data = try? Data(contentsOf: infoPlist),
       let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
        var new = dict
        new["LSMultipleInstancesProhibited"] = false
        if let out = try? PropertyListSerialization.data(fromPropertyList: new, format: .binary, options: 0) {
            try? out.write(to: infoPlist)
        }
    }

    // Break semaphore
    _ = sem_unlink("/RobloxPlayerUniq")

    // Open
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    open.arguments = ["-n", "-a", targetApp.path, url]
    try? open.run()
    open.waitUntilExit()

    print("launched via clone: \(targetApp.path)")
}

run()


