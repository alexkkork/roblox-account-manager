import Foundation
import AppKit
import Combine
import CoreServices

@MainActor
class MultiLauncher: ObservableObject {
    @Published var activeLaunches: [LaunchSession] = []
    @Published var isLaunching = false
    @Published var error: AppError?
    @Published var launchQueue: [LaunchRequest] = []
    
    private let maxConcurrentLaunches = 10
    private var launchTasks: [UUID: Task<Void, Never>] = [:]
    private var deepLinkTemplate: DeepLinkTemplate?
    private var cloneCounter: Int = 1
    private var lastScriptCount: Int = -1
    private var accountInstanceMap: [UUID: Int] = [:]
    
    // Executor injection plan: before opening robloxN: link, ensure the matching Roblox app bundle
    // has the assigned executor's DYLD_INSERT_LIBRARIES pointing to the executor's dylibs.
    // We'll set a temporary environment for the launched process when we directly exec, but since
    // we use URL scheme open, we instead write a per-instance wrapper plist into '~/Library/LaunchAgents'
    // is out of scope for now. Minimal viable: update settings only and let user's script perform actual dylib injection.
    
    // MARK: - Launch Management
    // MARK: - Deep Link Handling
    func handleInboundURL(_ url: URL) {
        debugLog("DeepLink", "Received URL=\(url.absoluteString)")
        // Capture template from real browser deep link for robust future launches
        captureDeepLinkTemplate(from: url)
        // Minimal: just open the URL via clone path to spawn new instance
        Task { [weak self] in
            guard let self else { return }
            let baseline = snapshotRobloxPIDs()
            let workspace = NSWorkspace.shared
            let handler = workspace.urlForApplication(toOpen: URL(string: "roblox-player:")!)
            if let handler {
                do {
                    let clone = try makeRobloxClone(from: handler)
                    breakSingleInstanceGuard()
                    openViaOpenTool(appPath: clone, with: url)
                    _ = await detectNewRobloxPID(after: baseline, timeoutSeconds: 40.0)
                    // Flip prohibition AFTER first successful open
                    breakSingleInstanceGuard()
                    Task { self.setMultipleInstancesProhibition(appBundlePath: clone, prohibited: false) }
                } catch {
                    debugLog("DeepLink", "Clone open failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func captureDeepLinkTemplate(from url: URL) {
        let s = url.absoluteString
        guard let giRange = s.range(of: "gameinfo:"),
              let nextSep = s[giRange.upperBound...].firstIndex(of: "+") else { return }
        let prefix = String(s[..<giRange.upperBound])
        let suffix = String(s[nextSep...])
        deepLinkTemplate = DeepLinkTemplate(prefix: prefix, suffix: suffix)
        debugLog("URLHandler", "Stored deep link template")
    }

    // MARK: - URL Handler Registration (no-op; we use prepared clones only)
    func ensureDefaultURLHandler() { debugLog("URLHandler", "Using prepared clones; not changing default handler") }
    
    init() {
        // Observe account count changes to reconfigure external helper
        NotificationCenter.default.addObserver(forName: .accountsChanged, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            if let count = note.userInfo?["count"] as? Int {
                self.configureExternalInstances(count: count)
            }
        }
    }
    
    // MARK: - External helper script integration
    func configureExternalInstances(count: Int) {
        guard count >= 0 else { return }
        if count == lastScriptCount { return }
        lastScriptCount = count
        let c = count
        DispatchQueue.global(qos: .background).async {
            self.runMultiInstanceScript(count: c)
            // After preparing robloxN schemes, also apply executor injections per assignments
            DispatchQueue.main.async {
                // Obtain settingsManager via app environment
                // Since we can't get EnvironmentObject here directly, post a notification
                NotificationCenter.default.post(name: .init("applyExecutorsToClones"), object: nil, userInfo: ["count": c])
            }
        }
    }
    
    private func runMultiInstanceScript(count: Int) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let scriptURL = support.appendingPathComponent("RobloxAccountManager/multi-instance.sh")
        let path = scriptURL.path
        guard FileManager.default.fileExists(atPath: path) else {
            print("[ExternalScript] Script not found at \(path)")
            return
        }
        // Ensure executable bit
        _ = chmod(path, 0o755)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = [path, String(count)]
        let outPipe = Pipe(); proc.standardOutput = outPipe
        let errPipe = Pipe(); proc.standardError = errPipe
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus != 0 {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                print("[ExternalScript] Exit=\(proc.terminationStatus) error=\(err)")
            } else {
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                print("[ExternalScript] OK count=\(count)\n\(out)")
            }
        } catch {
            print("[ExternalScript] Failed to run: \(error.localizedDescription)")
        }
    }
    
    func launchGame(account: Account, game: Game, customSettings: LaunchSettings? = nil, flavor: RobloxFlavor = .clean) {
        let request = LaunchRequest(
            account: account,
            game: game,
            launchSettings: customSettings ?? account.customLaunchSettings,
            flavor: flavor,
            requestedAt: Date()
        )
        
        if activeLaunches.count >= maxConcurrentLaunches {
            launchQueue.append(request)
            return
        }
        
        performLaunch(request)
    }
    
    func launchMultipleAccounts(accounts: [Account], game: Game, flavor: RobloxFlavor = .clean) {
        for account in accounts {
            launchGame(account: account, game: game, flavor: flavor)
        }
    }
    
    func launchAccountsWithDifferentGames(_ accountGamePairs: [(Account, Game)], flavor: RobloxFlavor = .clean) {
        for (account, game) in accountGamePairs {
            launchGame(account: account, game: game, flavor: flavor)
        }
    }

    // MARK: - Group Launch (near-simultaneous)
    func launchGroup(accounts: [Account], game: Game, staggerMs: Int = 120, flavor: RobloxFlavor = .clean) {
        let effective = Array(accounts.prefix(maxConcurrentLaunches))
        Task {
            await withTaskGroup(of: Void.self) { group in
                for (idx, account) in effective.enumerated() {
                    group.addTask { [weak self] in
                        guard let self = self else { return }
                        // Optional tiny stagger to avoid identical timestamps
                        if idx > 0 { try? await Task.sleep(nanoseconds: UInt64(staggerMs * 1_000_000)) }
                        await MainActor.run { self.launchGame(account: account, game: game, flavor: flavor) }
                    }
                }
            }
        }
    }

    // MARK: - Triple Launch (warm-up + double + reinforce)
    func launchDoublePlusOne(accounts: [Account], game: Game, flavor: RobloxFlavor = .clean) {
        let firstTwo = Array(accounts.prefix(2))
        guard firstTwo.count == 2 else { return }
        Task {
            // First pass: near-simultaneous two
            await withTaskGroup(of: Void.self) { group in
                for (idx, account) in firstTwo.enumerated() {
                    group.addTask { [weak self] in
                        guard let self = self else { return }
                        if idx > 0 { try? await Task.sleep(nanoseconds: 80_000_000) }
                        await MainActor.run { self.launchGame(account: account, game: game, flavor: flavor) }
                    }
                }
            }
            // Small delay, then re-fire the second to mitigate 403 timing
            try? await Task.sleep(nanoseconds: 250_000_000)
            if let second = firstTwo.last {
                await MainActor.run { self.launchGame(account: second, game: game, flavor: flavor) }
            }
        }
    }

    // MARK: - Triple-burst for two accounts (3 cycles total)
    func launchGroupTripleBurst(accounts: [Account], game: Game, bursts: Int = 3, staggerBetweenAccountsMs: Int = 80, delayBetweenBurstsMs: Int = 180) {
        let pair = Array(accounts.prefix(2))
        guard pair.count == 2 else { return }
        Task {
            for b in 0..<bursts {
                await withTaskGroup(of: Void.self) { group in
                    for (idx, account) in pair.enumerated() {
                        group.addTask { [weak self] in
                            guard let self = self else { return }
                            if idx > 0 { try? await Task.sleep(nanoseconds: UInt64(staggerBetweenAccountsMs * 1_000_000)) }
                            await MainActor.run { self.launchGame(account: account, game: game) }
                        }
                    }
                }
                if b < bursts - 1 { try? await Task.sleep(nanoseconds: UInt64(delayBetweenBurstsMs * 1_000_000)) }
            }
        }
    }
    
    private func performLaunch(_ request: LaunchRequest) {
        let sessionId = UUID()
        let session = LaunchSession(
            id: sessionId,
            account: request.account,
            game: request.game,
            launchSettings: request.launchSettings,
            status: .launching,
            startedAt: Date()
        )
        
        activeLaunches.append(session)
        
        let task = Task {
            await executeLaunch(sessionId: sessionId, request: request)
        }
        
        launchTasks[sessionId] = task
    }
    
    private func executeLaunch(sessionId: UUID, request: LaunchRequest) async {
        guard let sessionIndex = activeLaunches.firstIndex(where: { $0.id == sessionId }) else { return }
        
        do {
            debugLog("Launch", "Starting launch for account=\(request.account.username) placeId=\(request.game.placeId)")
            // Update status to launching
            activeLaunches[sessionIndex].status = .launching
            
            // Get auth ticket and CSRF token (403s can occur if reused; fetch fresh per account)
            let authData = try await RobloxAPIService.shared.getAuthTicketForLaunch(from: request.account.cookie)
            debugLog("Launch", "Got CSRF len=\(authData.csrfToken.count) ticket len=\(authData.authTicket.count)")
            
            // Decide launch path: open the selected clone app and pass roblox-player deep link as argument
            let instanceNo = resolveInstanceNumber(for: request.account)
            // Optional: lookup assigned executor for this instance and invoke script to inject before open (kept as-is)
            if let settingsManager = try? await MainActor.run(body: { () -> SettingsManager? in
                // Attempt to get via shared SwiftUI environment is not trivial here; use Notification or singleton if present.
                return nil
            }) {
                if let execId = settingsManager.assignedExecutorId(forInstance: instanceNo),
                   let exec = settingsManager.settings.executors.first(where: { $0.id == execId }),
                   let installed = exec.installedPath {
                    // Run the user's script with ACTION=inject to apply dylibs to the prepared roblox instance
                    let script = exec.installURLString
                    var scriptPath = script
                    if script.lowercased().hasPrefix("http://") || script.lowercased().hasPrefix("https://") {
                        // Expect already downloaded during install; skip
                        scriptPath = (installed as NSString).appendingPathComponent("install.sh")
                    }
                    _ = chmod(scriptPath, 0o755)
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    p.arguments = [scriptPath]
                    var env = ProcessInfo.processInfo.environment
                    env["ACTION"] = "inject"
                    env["EXECUTOR_INSTALL_DIR"] = installed
                    env["INSTANCE_INDEX"] = String(instanceNo)
                    if let clones = (try? await MainActor.run { () -> String in
                        // Read from settings; default to ~/Roblox-*.app directory
                        let dir = settingsManager.settings.robloxClonesDirectory
                        return dir.isEmpty ? NSHomeDirectory() : dir
                    }) { env["ROBLOX_CLONES_DIR"] = clones }
                    p.environment = env
                    do { try p.run(); p.waitUntilExit() } catch { /* ignore */ }
                }
            }
            // Build roblox-player deep link
            let deepLink = buildRobloxLaunchURL(placeId: request.game.placeId, authTicket: authData.authTicket, placeURL: "https://www.roblox.com/games/\(request.game.placeId)")
            // Resolve clone app path for flavor and instance
            if let appPath = cloneAppPath(for: request.flavor, instance: instanceNo) {
                debugLog("Launch", "Opening clone app=\(appPath) with deep link")
                if let appURL = URL(string: appPath)?.isFileURL == true ? URL(string: appPath) : URL(fileURLWithPath: appPath) {
                    // For MacSploit, ensure ~/Applications/Roblox.app points to this clone (path expectations inside injected code)
                    if request.flavor == .macsploit { SettingsManager().ensureHomeApplicationsSymlink(to: appPath) }
                    // Prefer launching the app's executable directly with a clean environment to avoid Metal debug crashes
                    let baseline = snapshotRobloxPIDs()
                    if let exeURL = findExecutable(inAppAt: appURL) {
                        var env: [String: String] = [:]
                        // Minimal clean environment
                        env["HOME"] = NSHomeDirectory()
                        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
                        let supportBase = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? URL(fileURLWithPath: NSTemporaryDirectory())
                        let unique = supportBase.appendingPathComponent("RobloxAccountManager/Instance-\(UUID().uuidString)", isDirectory: true)
                        try? FileManager.default.createDirectory(at: unique, withIntermediateDirectories: true)
                        let tmpDir = unique.appendingPathComponent("tmp", isDirectory: true)
                        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
                        env["TMPDIR"] = tmpDir.path + "/"
                        env["CFFIXED_USER_HOME"] = unique.path
                        // Disable Metal debug/validation layers that can cause aborts in third-party injected builds
                        env["MTL_DEBUG_LAYER"] = "0"
                        env["MTL_ENABLE_DEBUG_INFO"] = "0"
                        env["MTL_HUD_ENABLED"] = "0"
                        env["MTL_SHADER_VALIDATION"] = "0"
                        env["MallocNanoZone"] = "0"
                        // Launch
                        launchExecutable(exeURL: exeURL, urlArg: deepLink.absoluteString, environment: env)
                        if let pid = await detectNewRobloxPID(after: baseline, timeoutSeconds: 25.0) {
                            activeLaunches[sessionIndex].processId = pid
                        }
                    } else {
                        // Fallback to workspace open if we couldn't find the binary
                        _ = try? await openApplication(at: appURL, urlArg: deepLink.absoluteString, activates: true)
                    }
                    activeLaunches[sessionIndex].appClonePath = appPath
                    // Send explicit GURL AppleEvent to the clone so it handles the roblox-player URL
                    let bundleId = bundleIdForClone(flavor: request.flavor, instance: instanceNo)
                    sendDeepLinkToBundleId(bundleId: bundleId, url: deepLink)
                    // Optionally open companion app for selected flavor
                    openCompanionAppIfNeeded(for: request.flavor)
                }
            } else {
                debugLog("Launch", "Clone app not found for flavor=\(request.flavor) instance=\(instanceNo). Aborting launch.")
                if let idx = activeLaunches.firstIndex(where: { $0.id == sessionId }) {
                    activeLaunches[idx].status = .failed
                    activeLaunches[idx].error = "Missing clones for \(request.flavor). Use Finalize Multi-Instance first."
                    activeLaunches[idx].endedAt = Date()
                }
                return
            }
            activeLaunches[sessionIndex].processId = nil
            activeLaunches[sessionIndex].status = .running
            activeLaunches[sessionIndex].launchedAt = Date()
            
        } catch {
            // Update session with error
            if let sessionIndex = activeLaunches.firstIndex(where: { $0.id == sessionId }) {
                activeLaunches[sessionIndex].status = .failed
                activeLaunches[sessionIndex].error = error.localizedDescription
                activeLaunches[sessionIndex].endedAt = Date()
            }
            
            self.error = AppError.launchError(error.localizedDescription)
        }
        
        // Clean up
        launchTasks.removeValue(forKey: sessionId)
        
        // Process queue if available
        processLaunchQueue()
    }
    
    private func buildRobloxLaunchURL(placeId: Int, authTicket: String, placeURL: String) -> URL {
        // Roblox macOS launcher expects PlaceLauncher.ashx URL in placelauncherurl
        let placeLauncher = "https://assetgame.roblox.com/game/PlaceLauncher.ashx?request=RequestGame&placeId=\(placeId)"
        // Encode launcher URL (strict)
        let encodedLauncher = placeLauncher.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? placeLauncher
        // Encode gameinfo to avoid '+' being parsed as a field separator
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        let encodedTicket = authTicket.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: "+", with: "%2B") ?? authTicket.replacingOccurrences(of: "+", with: "%2B")
        let urlString = "roblox-player:1+launchmode:play+gameinfo:\(encodedTicket)+placelauncherurl:\(encodedLauncher)"
        return URL(string: urlString) ?? URL(string: "roblox://placeId=\(placeId)")!
    }

    private func buildRobloxLaunchURL(placeId: Int, authTicket: String, placeURL: String, schemeOverride: String) -> URL {
        // schemeOverride is like "roblox1:" (Roblox deep links use a colon, not ://)
        let placeLauncher = "https://assetgame.roblox.com/game/PlaceLauncher.ashx?request=RequestGame&placeId=\(placeId)"
        let encodedLauncher = placeLauncher.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? placeLauncher
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        let encodedTicket = authTicket.addingPercentEncoding(withAllowedCharacters: allowed)?.replacingOccurrences(of: "+", with: "%2B") ?? authTicket.replacingOccurrences(of: "+", with: "%2B")
        // Normalize provided scheme to the Roblox deep-link format (scheme:payload)
        let normalizedScheme: String = {
            if let range = schemeOverride.range(of: "://") {
                return String(schemeOverride[..<range.lowerBound]) + ":"
            } else if schemeOverride.hasSuffix(":") {
                return schemeOverride
            } else {
                return schemeOverride + ":"
            }
        }()
        let urlString = "\(normalizedScheme)1+launchmode:play+gameinfo:\(encodedTicket)+placelauncherurl:\(encodedLauncher)"
        return URL(string: urlString) ?? URL(string: "roblox-player:1+launchmode:play")!
    }

    private func resolveInstanceNumber(for account: Account) -> Int {
        if let n = accountInstanceMap[account.id] { return n }
        let total = max(1, lastScriptCount)
        let next = (accountInstanceMap.values.max() ?? 0) % total + 1
        accountInstanceMap[account.id] = next
        return next
    }

    private func debugLog(_ tag: String, _ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let ts = formatter.string(from: Date())
        print("[Launch][\(tag)][\(ts)] \(message)")
    }

    // MARK: - Public URL builder
    func buildJoinURL(account: Account, game: Game) async throws -> String {
        let authData = try await RobloxAPIService.shared.getAuthTicketForLaunch(from: account.cookie)
        var url = buildRobloxLaunchURL(
            placeId: game.placeId,
            authTicket: authData.authTicket,
            placeURL: "https://www.roblox.com/games/\(game.placeId)"
        )
        if let t = deepLinkTemplate {
            let safeTicket = authData.authTicket.replacingOccurrences(of: "+", with: "%2B")
            if let u = URL(string: t.prefix + safeTicket + t.suffix) { url = u }
        }
        return url.absoluteString
    }
    
    private func launchRobloxProcess(url: URL, account: Account, settings: LaunchSettings) async throws -> (Int32, String?) {
        // Deprecated path; retained for compatibility but unused in script-driven mode
        NSWorkspace.shared.open(url)
        return (0, nil)
    }

    // MARK: - Single-instance guard breakers
    private func breakSingleInstanceGuard() {}

    private func setMultipleInstancesProhibition(appBundlePath: String, prohibited: Bool) {
        let infoPlist = URL(fileURLWithPath: appBundlePath)
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoPlist) else { return }
        var format = PropertyListSerialization.PropertyListFormat.binary
        if var dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any] {
            dict["LSMultipleInstancesProhibited"] = prohibited
            if let newData = try? PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0) {
                try? newData.write(to: infoPlist)
            }
        }
    }

    private func setBackgroundCloneAttributes(appBundlePath: String, newName: String, bundleIdSuffix: String) {
        let infoPlist = URL(fileURLWithPath: appBundlePath)
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoPlist) else { return }
        var format = PropertyListSerialization.PropertyListFormat.binary
        if var dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any] {
            let originalId = (dict["CFBundleIdentifier"] as? String) ?? "com.roblox.Roblox"
            dict["CFBundleName"] = newName
            dict["CFBundleDisplayName"] = newName
            dict["CFBundleIdentifier"] = originalId + ".multi." + bundleIdSuffix
            dict["LSUIElement"] = true // Hide from Dock/menu bar
            dict["LSMultipleInstancesProhibited"] = false
            if let newData = try? PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0) {
                try? newData.write(to: infoPlist)
            }
        }
    }

    private func adHocSignApp(at appBundlePath: String) {
        // codesign --force --deep --sign - <app>
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        proc.arguments = ["--force", "--deep", "--sign", "-", appBundlePath]
        do { try proc.run(); proc.waitUntilExit() } catch { /* ignore */ }
    }

    private func cloneId(from appBundlePath: String) -> String {
        // Extract the last directory name used for the clone container
        let url = URL(fileURLWithPath: appBundlePath)
        let container = url.deletingLastPathComponent() // remove Roblox.app
        let id = container.lastPathComponent
        return id
    }

    private func removeQuarantine(from appBundlePath: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        proc.arguments = ["-d", "com.apple.quarantine", appBundlePath]
        do { try proc.run() } catch { /* ignore */ }
    }

    private func openApplication(at appURL: URL, urlArg: String, activates: Bool) async throws -> NSRunningApplication? {
        let workspace = NSWorkspace.shared
        let config = NSWorkspace.OpenConfiguration()
        config.activates = activates
        config.createsNewApplicationInstance = true
        config.arguments = [urlArg]
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSRunningApplication?, Error>) in
            workspace.openApplication(at: appURL, configuration: config) { app, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume(returning: app) }
            }
        }
    }

    private func cloneAppPath(for flavor: RobloxFlavor, instance: Int) -> String? {
        let fm = FileManager.default
        let settings = SettingsManager()
        let path: String
        switch flavor {
        case .clean:
            let dir = settings.defaultClonesDirectory()
            path = (dir as NSString).appendingPathComponent("Roblox-\(instance).app")
        case .opiumware:
            let dir = settings.opiumwareClonesDirectory()
            path = (dir as NSString).appendingPathComponent("roblox-opiumware-\(instance).app")
        case .macsploit:
            let dir = settings.macsploitClonesDirectory()
            path = (dir as NSString).appendingPathComponent("macsploit-roblox-\(instance).app")
        case .hydrogen:
            let dir = settings.hydrogenClonesDirectory()
            path = (dir as NSString).appendingPathComponent("hydrogen-roblox-\(instance).app")
        }
        return fm.fileExists(atPath: path) ? path : nil
    }

    private func openViaOpenTool(appPath: String, with url: URL) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        // Use -a <app> <url> so the system sends a GURL event directly to the Roblox app
        proc.arguments = ["-n", "-a", appPath, url.absoluteString]
        do { try proc.run() } catch { debugLog("Launch", "open tool failed: \(error.localizedDescription)") }
    }

    private func findExecutable(inAppAt appURL: URL) -> URL? {
        let macOSDir = appURL.appendingPathComponent("Contents/MacOS", isDirectory: true)
        guard let items = try? FileManager.default.contentsOfDirectory(at: macOSDir, includingPropertiesForKeys: [.isExecutableKey], options: []) else { return nil }
        // Pick the first executable file
        for item in items {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), !isDir.boolValue {
                if let vals = try? item.resourceValues(forKeys: [.isExecutableKey]), vals.isExecutable == true {
                    // Prefer RobloxPlayer if present
                    if item.lastPathComponent.contains("RobloxPlayer") { return item }
                    return item
                }
            }
        }
        return nil
    }

    private func bundleIdForClone(flavor: RobloxFlavor, instance: Int) -> String {
        switch flavor {
        case .clean:
            return "com.roblox.client.instance\(instance)"
        case .opiumware:
            return "com.roblox.client.opiumware.instance\(instance)"
        case .macsploit:
            return "com.roblox.client.macsploit.instance\(instance)"
        case .hydrogen:
            return "com.roblox.client.hydrogen.instance\(instance)"
        }
    }

    private func openCompanionAppIfNeeded(for flavor: RobloxFlavor) {
        let fm = FileManager.default
        let path: String?
        switch flavor {
        case .clean:
            path = nil
        case .opiumware:
            path = "/Applications/Opiumware.app"
        case .macsploit:
            path = "/Applications/MacSploit.app"
        case .hydrogen:
            path = nil
        }
        guard let p = path, fm.fileExists(atPath: p) else { return }
        let url = URL(fileURLWithPath: p)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    private func sendDeepLinkToBundleId(bundleId: String, url: URL) {
        // Fire-and-forget AppleScript on a background thread to avoid blocking the main actor
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            on run argv
                set targetBundleId to item 1 of argv
                set targetURL to item 2 of argv
                tell application id targetBundleId to open location targetURL
            end run
            """
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("send_gurl.scpt")
            do {
                try script.data(using: .utf8)?.write(to: tmp)
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                p.arguments = [tmp.path, bundleId, url.absoluteString]
                try p.run(); p.waitUntilExit()
            } catch {
                self.debugLog("Launch", "Failed to send GURL to \(bundleId): \(error.localizedDescription)")
            }
        }
    }

    private func robloxBaseAppURL() -> URL? {
        // Resolve the Roblox Player app location
        let candidates = [
            "/Applications/Roblox.app",
            "~/Applications/Roblox.app".replacingOccurrences(of: "~", with: NSHomeDirectory())
        ]
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        // Fallback to workspace resolution by scheme
        return NSWorkspace.shared.urlForApplication(toOpen: URL(string: "roblox-player:")!)
    }

    // Create a new ephemeral clone under ~/Library/Application Support/RobloxAccountManager/Ephemeral/<n>/Multi-Instance Roblox <n>.app
    private func prepareNextEphemeralClone() -> String { return "" }

    private func runPlistBuddy(path: String, command: String) {
        let pb = Process()
        pb.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
        pb.arguments = ["-c", command, path]
        let pipe = Pipe(); pb.standardError = pipe
        try? pb.run(); pb.waitUntilExit()
    }

    private func updateCloneInfoPlist(at appPath: String, friendlyName: String, suffix: String) {
        let plistURL = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { return }
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard var dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any]) else { return }
        // Identify current exec name and verify
        let macOSDir = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/MacOS", isDirectory: true)
        var execName = (dict["CFBundleExecutable"] as? String) ?? "RobloxPlayer"
        let execPath = macOSDir.appendingPathComponent(execName)
        if !FileManager.default.fileExists(atPath: execPath.path) {
            // Prefer RobloxPlayer if present; else first executable file
            if FileManager.default.fileExists(atPath: macOSDir.appendingPathComponent("RobloxPlayer").path) {
                execName = "RobloxPlayer"
            } else if let items = try? FileManager.default.contentsOfDirectory(at: macOSDir, includingPropertiesForKeys: [.isExecutableKey]) {
                if let firstExec = items.first(where: { (try? $0.resourceValues(forKeys: [.isExecutableKey]).isExecutable) ?? false }) {
                    execName = firstExec.lastPathComponent
                }
            }
        }
        // Ensure executable bit
        _ = chmod(macOSDir.appendingPathComponent(execName).path, 0o755)
        // Update identity and display names (no .app in names)
        let originalId = (dict["CFBundleIdentifier"] as? String) ?? "com.roblox.Roblox"
        dict["CFBundleIdentifier"] = originalId + "." + suffix
        dict["CFBundleName"] = friendlyName
        dict["CFBundleDisplayName"] = friendlyName
        dict["CFBundleExecutable"] = execName
        dict["LSMultipleInstancesProhibited"] = false
        // Remove URL handlers so default scheme handler remains the original install
        dict.removeValue(forKey: "CFBundleURLTypes")
        if let newData = try? PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0) {
            try? newData.write(to: plistURL)
        }
    }

    private func buildIsolatedEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let unique = base.appendingPathComponent("RobloxAccountManager/Instance-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: unique, withIntermediateDirectories: true)
        let tmpDir = unique.appendingPathComponent("tmp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        env["TMPDIR"] = tmpDir.path + "/"
        env["CFFIXED_USER_HOME"] = unique.path
        return env
    }

    private func launchExecutable(exeURL: URL, urlArg: String, environment: [String: String]) {
        let proc = Process()
        proc.executableURL = exeURL
        proc.arguments = [urlArg]
        proc.environment = environment
        do { try proc.run() } catch { debugLog("Launch", "exec failed: \(error.localizedDescription)") }
    }

    // MARK: - CLI integration
    private func cliBinaryURL() -> URL? {
        // Prefer release build location; fall back to debug
        let base = URL(fileURLWithPath: NSHomeDirectory())
        let projectRootCandidates = [
            "/Users/alex/Developer/roblox-account-manager/RobloxMultiCLI/.build/release/robloxmulti",
            "/Users/alex/Developer/roblox-account-manager/RobloxMultiCLI/.build/debug/robloxmulti"
        ]
        for path in projectRootCandidates {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }

    private func launchViaCLI(url: URL) async -> Int32? {
        guard let bin = cliBinaryURL() else { return nil }
        let baseline = snapshotRobloxPIDs()
        let proc = Process()
        proc.executableURL = bin
        proc.arguments = [url.absoluteString]
        do { try proc.run() } catch { debugLog("Launch", "CLI failed: \(error.localizedDescription)"); return nil }
        // Wait briefly and detect new PID
        if let pid = await detectNewRobloxPID(after: baseline, timeoutSeconds: 20.0) { return pid }
        return nil
    }

    private func isRobloxApp(_ app: NSRunningApplication) -> Bool {
        if let bid = app.bundleIdentifier?.lowercased(), bid.contains("roblox") { return true }
        if let name = app.localizedName?.lowercased(), name.contains("roblox") { return true }
        return false
    }
    
    private func warmUpRoblox() async {}
    
    private func snapshotRobloxPIDs() -> Set<Int32> {
        let apps = NSWorkspace.shared.runningApplications.filter { isRobloxApp($0) }
        return Set(apps.map { $0.processIdentifier })
    }

    private func makeRobloxClone(from appURL: URL) throws -> String {
        // Create a unique container directory and copy Roblox.app into it, preserving attributes
        let supportBase = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let clonesRoot = supportBase.appendingPathComponent("RobloxAccountManager/Clones", isDirectory: true)
        if !FileManager.default.fileExists(atPath: clonesRoot.path) {
            try FileManager.default.createDirectory(at: clonesRoot, withIntermediateDirectories: true)
        }
        let container = clonesRoot.appendingPathComponent(UUID().uuidString.prefix(8).description, isDirectory: true)
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        let targetApp = container.appendingPathComponent("Roblox.app")
        // Use cp -a to preserve code signature and xattrs exactly
        let cp = Process()
        cp.executableURL = URL(fileURLWithPath: "/bin/cp")
        cp.arguments = ["-a", appURL.path, container.path]
        try cp.run(); cp.waitUntilExit()
        // Return the path to the cloned app
        return targetApp.path
    }
    
    private func detectNewRobloxPID(after baseline: Set<Int32>, timeoutSeconds: Double) async -> Int32? {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            let current = snapshotRobloxPIDs()
            let newOnes = current.subtracting(baseline)
            if let pid = newOnes.first {
                return pid
            }
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        }
        return nil
    }
    
    private func monitorProcess(sessionId: UUID, processId: Int32) async {
        // Monitor the process and update session status
        while let sessionIndex = activeLaunches.firstIndex(where: { $0.id == sessionId }) {
            let session = activeLaunches[sessionIndex]
            
            if session.status == .terminating || session.status == .terminated {
                break
            }
            
            // Check if process is still running
            let isRunning = isProcessRunning(processId)
            
            if !isRunning {
                activeLaunches[sessionIndex].status = .terminated
                activeLaunches[sessionIndex].endedAt = Date()
                // Cleanup ephemeral clone on natural exit
                if let clonePath = activeLaunches[sessionIndex].appClonePath, !clonePath.isEmpty {
                    do {
                        // Remove the entire container directory when it matches our Ephemeral structure
                        let container = URL(fileURLWithPath: clonePath).deletingLastPathComponent()
                        try FileManager.default.removeItem(at: container)
                        debugLog("Launch", "Removed clone at \(clonePath)")
                    } catch {
                        debugLog("Launch", "Failed removing clone: \(error.localizedDescription)")
                    }
                    activeLaunches[sessionIndex].appClonePath = nil
                }
                break
            }
            
            // Wait before next check
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
    }
    
    private func isProcessRunning(_ processId: Int32) -> Bool {
        // Check if a process with the given PID is still running
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.processIdentifier == processId }
    }
    
    private func processLaunchQueue() {
        guard !launchQueue.isEmpty && activeLaunches.count < maxConcurrentLaunches else { return }
        
        let nextRequest = launchQueue.removeFirst()
        performLaunch(nextRequest)
    }
    
    // MARK: - Session Management
    
    func terminateSession(_ sessionId: UUID) {
        guard let sessionIndex = activeLaunches.firstIndex(where: { $0.id == sessionId }) else { return }
        
        let session = activeLaunches[sessionIndex]
        activeLaunches[sessionIndex].status = .terminating
        
        if let processId = session.processId {
            terminateProcess(processId)
        }
        
        // Cancel the monitoring task
        launchTasks[sessionId]?.cancel()
        launchTasks.removeValue(forKey: sessionId)
        
        // Update session status
        activeLaunches[sessionIndex].status = .terminated
        activeLaunches[sessionIndex].endedAt = Date()
        
        // Cleanup clone if it was created
        if let clonePath = activeLaunches[sessionIndex].appClonePath, !clonePath.isEmpty {
            do {
                try FileManager.default.removeItem(atPath: clonePath)
                debugLog("Launch", "Removed clone at \(clonePath)")
            } catch {
                debugLog("Launch", "Failed removing clone: \(error.localizedDescription)")
            }
            activeLaunches[sessionIndex].appClonePath = nil
        }
    }
    
    func terminateAllSessions() {
        for session in activeLaunches where session.status == .running {
            terminateSession(session.id)
        }
    }
    
    func terminateSessionsForAccount(_ account: Account) {
        let sessionsToTerminate = activeLaunches.filter { $0.account.id == account.id && $0.status == .running }
        for session in sessionsToTerminate {
            terminateSession(session.id)
        }
    }
    
    private func terminateProcess(_ processId: Int32) {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.processIdentifier == processId }) {
            app.terminate()
        }
    }
    
    // MARK: - Session Queries
    
    func getActiveSessions() -> [LaunchSession] {
        return activeLaunches.filter { $0.status == .running }
    }
    
    func getSessionsForAccount(_ account: Account) -> [LaunchSession] {
        return activeLaunches.filter { $0.account.id == account.id }
    }
    
    func getSessionsForGame(_ game: Game) -> [LaunchSession] {
        return activeLaunches.filter { $0.game.id == game.id }
    }
    
    func canLaunchMore() -> Bool {
        return activeLaunches.filter { $0.status == .running }.count < maxConcurrentLaunches
    }
    
    // MARK: - Statistics
    
    func getLaunchStatistics() -> LaunchStatistics {
        let now = Date()
        let dayAgo = now.addingTimeInterval(-86400) // 24 hours ago
        
        let recentSessions = activeLaunches.filter { $0.startedAt >= dayAgo }
        let successfulLaunches = recentSessions.filter { $0.status == .terminated && $0.error == nil }.count
        let failedLaunches = recentSessions.filter { $0.status == .failed }.count
        
        let totalPlayTime = recentSessions.compactMap { session in
            guard let endTime = session.endedAt ?? (session.status == .running ? now : nil),
                  let startTime = session.launchedAt else { return nil }
            return endTime.timeIntervalSince(startTime)
        }.reduce(0.0, +)
        
        return LaunchStatistics(
            totalLaunches: recentSessions.count,
            successfulLaunches: successfulLaunches,
            failedLaunches: failedLaunches,
            averagePlayTime: recentSessions.isEmpty ? 0 : totalPlayTime / Double(recentSessions.count),
            currentActiveSessions: getActiveSessions().count
        )
    }
    
    // MARK: - Cleanup
    
    func cleanupCompletedSessions() {
        let cutoffDate = Date().addingTimeInterval(-3600) // 1 hour ago
        activeLaunches.removeAll { session in
            (session.status == .terminated || session.status == .failed) &&
            (session.endedAt ?? Date()) < cutoffDate
        }
    }
}

// MARK: - Supporting Types

struct LaunchRequest {
    let account: Account
    let game: Game
    let launchSettings: LaunchSettings
    let flavor: RobloxFlavor
    let requestedAt: Date
}

struct LaunchSession: Identifiable {
    let id: UUID
    let account: Account
    let game: Game
    let launchSettings: LaunchSettings
    var status: LaunchStatus
    let startedAt: Date
    var launchedAt: Date?
    var endedAt: Date?
    var processId: Int32?
    var error: String?
    var appClonePath: String?
    
    var duration: TimeInterval? {
        guard let launchedAt = launchedAt else { return nil }
        let endTime = endedAt ?? (status == .running ? Date() : launchedAt)
        return endTime.timeIntervalSince(launchedAt)
    }
}

enum LaunchStatus: String, CaseIterable {
    case launching = "launching"
    case running = "running"
    case terminating = "terminating"
    case terminated = "terminated"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .launching: return "Launching"
        case .running: return "Running"
        case .terminating: return "Terminating"
        case .terminated: return "Terminated"
        case .failed: return "Failed"
        }
    }
    
    var color: NSColor {
        switch self {
        case .launching: return .systemOrange
        case .running: return .systemGreen
        case .terminating: return .systemYellow
        case .terminated: return .systemGray
        case .failed: return .systemRed
        }
    }
}

struct LaunchStatistics {
    let totalLaunches: Int
    let successfulLaunches: Int
    let failedLaunches: Int
    let averagePlayTime: TimeInterval
    let currentActiveSessions: Int
    
    var successRate: Double {
        guard totalLaunches > 0 else { return 0 }
        return Double(successfulLaunches) / Double(totalLaunches)
    }
}

// MARK: - Template
private struct DeepLinkTemplate {
    let prefix: String
    let suffix: String
}
