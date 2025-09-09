import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    @Published var isLoading = false
    @Published var error: AppError?
    
    private let storage = SecureStorage.shared
    private let fileName = "settings.json"
    
    init() {
        self.settings = AppSettings()
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    func updateTheme(_ theme: AppTheme) {
        settings.theme = theme
        saveSettings()
    }
    
    func updateAccentColor(_ color: AccentColorOption) {
        settings.accentColor = color
        saveSettings()
    }
    
    func toggleAnimations() {
        settings.enableAnimations.toggle()
        saveSettings()
    }

    func toggleBeautifulMode() {
        settings.beautifulMode.toggle()
        saveSettings()
    }
    
    func toggleNotifications() {
        settings.enableNotifications.toggle()
        saveSettings()
    }
    
    func toggleAutoLaunch() {
        settings.autoLaunchOnStartup.toggle()
        saveSettings()
        
        if settings.autoLaunchOnStartup {
            enableAutoLaunch()
        } else {
            disableAutoLaunch()
        }
    }
    
    func updateMaxSimultaneousLaunches(_ count: Int) {
        settings.maxSimultaneousLaunches = max(1, min(10, count))
        saveSettings()
    }
    
    func toggleSoundEffects() {
        settings.enableSoundEffects.toggle()
        saveSettings()
    }
    
    func toggleHapticFeedback() {
        settings.enableHapticFeedback.toggle()
        saveSettings()
    }
    
    // MARK: - Default Quick Launch
    func setDefaultQuickLaunch(game: Game?) {
        if let game = game {
            settings.defaultQuickLaunchPlaceId = game.placeId
            settings.defaultQuickLaunchUniverseId = game.universeId
            settings.defaultQuickLaunchName = game.name
            settings.defaultQuickLaunchIconURL = game.thumbnailURL
        } else {
            settings.defaultQuickLaunchPlaceId = nil
            settings.defaultQuickLaunchUniverseId = nil
            settings.defaultQuickLaunchName = nil
            settings.defaultQuickLaunchIconURL = nil
        }
        saveSettings()
    }
    
    func updateDataStoragePath(_ path: String) {
        settings.dataStoragePath = path
        saveSettings()
    }
    
    func toggleEncryption() {
        settings.encryptionEnabled.toggle()
        saveSettings()
    }
    
    func toggleAutoBackup() {
        settings.autoBackup.toggle()
        saveSettings()
    }
    
    func updateBackupInterval(_ interval: BackupInterval) {
        settings.backupInterval = interval
        saveSettings()
    }
    
    func updateLanguage(_ language: AppLanguage) {
        settings.language = language
        saveSettings()
    }
    
    func updateWindowBehavior(_ behavior: WindowBehavior) {
        settings.windowBehavior = behavior
        saveSettings()
    }
    
    // MARK: - Executors Management
    func defaultExecutorsDirectory() -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("RobloxAccountManager/Executors", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }
    func addExecutor(name: String, installURLString: String) {
        var list = settings.executors
        list.append(Executor(name: name, installURLString: installURLString))
        settings.executors = list
        saveSettings()
    }
    
    func removeExecutor(_ executor: Executor) {
        settings.executors.removeAll { $0.id == executor.id }
        // Clean assignments that reference it
        settings.executorAssignmentsByInstance = settings.executorAssignmentsByInstance.filter { $0.value != executor.id }
        saveSettings()
    }
    
    func updateExecutor(_ executor: Executor) {
        if let idx = settings.executors.firstIndex(where: { $0.id == executor.id }) {
            settings.executors[idx] = executor
            saveSettings()
        }
    }
    
    func assignedExecutorId(forInstance instance: Int) -> UUID? {
        settings.executorAssignmentsByInstance[instance]
    }

    // MARK: - Install / Update Executor via user-provided script or URL
    func installOrUpdateExecutor(_ exec: Executor) {
        var executor = exec
        let fm = FileManager.default
        let baseDir: String = settings.executorsInstallDirectory.isEmpty ? defaultExecutorsDirectory() : settings.executorsInstallDirectory
        let targetDir = (baseDir as NSString).appendingPathComponent(exec.id.uuidString)
        try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        // Determine how to run: URL download, local script, or a command pipeline (curl ... | bash)
        let input = exec.installURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let isURL = input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://")
        let isExistingFile = FileManager.default.fileExists(atPath: input)
        let isCommand = !isURL && !isExistingFile

        var scriptPath: String? = nil
        if isURL {
            let tmpScript = (targetDir as NSString).appendingPathComponent("install_raw.sh")
            if let url = URL(string: input) {
                do {
                    let data = try Data(contentsOf: url)
                    try data.write(to: URL(fileURLWithPath: tmpScript))
                    scriptPath = tmpScript
                    _ = chmod(tmpScript, 0o755)
                } catch {
                    print("[Executor] Download failed: \(error.localizedDescription)")
                    return
                }
            } else { return }
        } else if isExistingFile {
            scriptPath = input
            _ = chmod(input, 0o755)
        }

        // Run installer with environment (ACTION=install)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let clonesDir = settings.robloxClonesDirectory.isEmpty ? defaultClonesDirectory() : settings.robloxClonesDirectory
        let targetRoblox = (clonesDir as NSString).appendingPathComponent("Roblox-1.app")
        if isCommand {
            // Pipe through sed to rewrite hardcoded destinations to our managed locations
            let cmd = "\(input) | true"
            let wrapped = "\(cmd)" // if input already includes a pipe, just run it
            let sedWrap = "( \(wrapped) ) | sed -e \"s#/Applications/Roblox.app#\(targetRoblox)#g\" -e \"s#/Applications/Opiumware.app#\(targetDir)/Opiumware.app#g\" | bash"
            proc.arguments = ["-lc", sedWrap]
        } else if let scriptPath {
            // cat script | sed ... | bash
            let sedWrap = "cat \"\(scriptPath)\" | sed -e \"s#/Applications/Roblox.app#\(targetRoblox)#g\" -e \"s#/Applications/Opiumware.app#\(targetDir)/Opiumware.app#g\" | bash"
            proc.arguments = ["-lc", sedWrap]
        } else {
            print("[Executor] Nothing to run (invalid input)")
            return
        }
        proc.currentDirectoryURL = URL(fileURLWithPath: targetDir)
        var env = ProcessInfo.processInfo.environment
        env["ACTION"] = "install"
        env["EXECUTOR_INSTALL_DIR"] = targetDir
        env["ROBLOX_CLONES_DIR"] = clonesDir
        proc.environment = env
        let errPipe = Pipe(); proc.standardError = errPipe
        let outPipe = Pipe(); proc.standardOutput = outPipe
        do { try proc.run(); proc.waitUntilExit() } catch {
            print("[Executor] Run failed: \(error.localizedDescription)")
            return
        }
        if proc.terminationStatus != 0 {
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("[Executor] Script exit=\(proc.terminationStatus) err=\(err)")
            // still proceed to index artifacts if any
        }

        // Index produced dylibs within install dir
        var dylibs: [String] = []
        if let enumerator = fm.enumerator(atPath: targetDir) {
            for case let file as String in enumerator {
                if file.lowercased().hasSuffix(".dylib") {
                    dylibs.append(file)
                }
            }
        }
        executor.installedPath = targetDir
        executor.dylibRelativePaths = dylibs
        updateExecutor(executor)

        // Move any created Roblox-* clones into desired directory
        moveClonesToDesiredDir()
        // After install/update, auto-inject into all prepared Roblox instances
        applyInjectionToAllClones(using: executor)
    }

    // MARK: - Discovery / Refresh
    func refreshExecutorsIndex() {
        let fm = FileManager.default
        var baseDir = settings.executorsInstallDirectory
        if baseDir.isEmpty { baseDir = defaultExecutorsDirectory() }
        guard fm.fileExists(atPath: baseDir) else { return }
        var discovered: [Executor] = []
        if let items = try? fm.contentsOfDirectory(atPath: baseDir) {
            for name in items {
                let path = (baseDir as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    // Collect dylibs
                    var dylibs: [String] = []
                    if let enumerator = fm.enumerator(atPath: path) {
                        for case let file as String in enumerator {
                            if file.lowercased().hasSuffix(".dylib") { dylibs.append(file) }
                        }
                    }
                    if !dylibs.isEmpty {
                        let exec = Executor(name: name, installURLString: "", installedPath: path, dylibRelativePaths: dylibs)
                        discovered.append(exec)
                    }
                }
            }
        }
        // Merge discovered with existing by installedPath
        for d in discovered {
            if let idx = settings.executors.firstIndex(where: { $0.installedPath == d.installedPath }) {
                var copy = settings.executors[idx]
                copy.name = d.name
                copy.dylibRelativePaths = d.dylibRelativePaths
                settings.executors[idx] = copy
            } else {
                settings.executors.append(d)
            }
        }
        saveSettings()
    }

    // MARK: - Script analysis → dylib extraction
    func analyzeInstallerScript(_ scriptText: String) -> (dylibURLs: [String], dylibNames: [String], targetPaths: [String]) {
        var dylibURLs: [String] = []
        var dylibNames: [String] = []
        var targetPaths: [String] = []
        let lines = scriptText.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("curl") && (trimmed.contains(".dylib") || trimmed.contains("libSystem.zip") || trimmed.contains("macsploit.dylib")) {
                if let url = extractURL(from: trimmed) { dylibURLs.append(url) }
            }
            if trimmed.contains("mv ") && trimmed.contains(".dylib") {
                if let name = extractDylibName(from: trimmed) { dylibNames.append(name) }
                if let target = extractTargetPath(from: trimmed) { targetPaths.append(target) }
            }
            if trimmed.contains("insert_dylib") || trimmed.contains("Patcher ") {
                if let target = extractTargetPath(from: trimmed) { targetPaths.append(target) }
            }
        }
        dylibURLs = Array(Set(dylibURLs))
        dylibNames = Array(Set(dylibNames))
        targetPaths = Array(Set(targetPaths))
        return (dylibURLs, dylibNames, targetPaths)
    }

    private func extractURL(from line: String) -> String? {
        // naive extraction of first http(s) URL
        guard let range = line.range(of: "https?://[\\w./%?=&:-]+", options: .regularExpression) else { return nil }
        return String(line[range])
    }

    private func extractDylibName(from line: String) -> String? {
        // look for *.dylib occurrences
        guard let range = line.range(of: "[A-Za-z0-9_./-]+\\.dylib", options: .regularExpression) else { return nil }
        let path = String(line[range])
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func extractTargetPath(from line: String) -> String? {
        // crude: find a path that starts with /Applications or ~/ or $HOME and ends with .dylib or app executable
        if let r = line.range(of: "/Applications/[A-Za-z0-9_ ./-]+", options: .regularExpression) {
            return String(line[r])
        }
        if let r = line.range(of: "[$]HOME/[A-Za-z0-9_ ./-]+", options: .regularExpression) {
            return String(line[r]).replacingOccurrences(of: "$HOME", with: NSHomeDirectory())
        }
        if let r = line.range(of: "~[A-Za-z0-9_ ./-]+", options: .regularExpression) {
            return (String(line[r]) as NSString).expandingTildeInPath
        }
        return nil
    }

    // MARK: - Patch dylib to instances directory
    func patchDylibToInstances(dylibAbsolutePath: String, instancesDir: String, maxInstances: Int = 10) {
        let fm = FileManager.default
        for i in 1...maxInstances {
            let app = (instancesDir as NSString).appendingPathComponent("Roblox-\(i).app")
            let target = (app as NSString).appendingPathComponent("Contents/MacOS")
            if fm.fileExists(atPath: target) {
                // Copy dylib next to binary
                let dest = (target as NSString).appendingPathComponent((dylibAbsolutePath as NSString).lastPathComponent)
                try? fm.removeItem(atPath: dest)
                do {
                    try fm.copyItem(atPath: dylibAbsolutePath, toPath: dest)
                    // Try to inject by patching the main binary using insert_dylib if present
                    let bin = (target as NSString).appendingPathComponent("RobloxPlayer")
                    let inserter = Bundle.main.path(forResource: "insert_dylib", ofType: nil) ?? "/usr/local/bin/insert_dylib"
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    p.arguments = ["-lc", "'\(inserter)' '\(dest)' '\(bin)' --strip-codesig --all-yes && mv '\(bin)_patched' '\(bin)' || true"]
                    try? p.run(); p.waitUntilExit()
                    // Remove quarantine and ad-hoc sign
                    let x = Process(); x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr"); x.arguments = ["-dr", "com.apple.quarantine", app]; try? x.run(); x.waitUntilExit()
                    let cs = Process(); cs.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); cs.arguments = ["--force", "--deep", "--sign", "-", "--timestamp=none", app]; try? cs.run(); cs.waitUntilExit()
                } catch {
                    print("[Patch] Failed for instance \(i): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Injection helpers
    private func applyInjectionToAllClones(using executor: Executor) {
        guard let installed = executor.installedPath else { return }
        let fm = FileManager.default
        var clonesDir = settings.robloxClonesDirectory
        if clonesDir.isEmpty {
            clonesDir = defaultClonesDirectory()
        }
        guard fm.fileExists(atPath: clonesDir) else { return }
        // Detect indices by checking for Roblox-<n>.app
        if let items = try? fm.contentsOfDirectory(atPath: clonesDir) {
            for name in items {
                if let idx = parseInstanceIndex(fromAppName: name) {
                    runInjectionScript(executor: executor, instanceIndex: idx, clonesDir: clonesDir)
                }
            }
        }
    }

    private func parseInstanceIndex(fromAppName name: String) -> Int? {
        // Expect formats like "Roblox-1.app" or custom; extract first integer
        let digits = name.compactMap { $0.isNumber ? $0 : nil }
        guard !digits.isEmpty, let idx = Int(String(digits)) else { return nil }
        return idx
    }

    private func runInjectionScript(executor: Executor, instanceIndex: Int, clonesDir: String) {
        let input = executor.installURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let isURL = input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://")
        let isExistingFile = FileManager.default.fileExists(atPath: input)
        let isCommand = !isURL && !isExistingFile
        var resolvedScript: String? = nil
        if isCommand {
            resolvedScript = nil
        } else if isExistingFile {
            resolvedScript = input
            _ = chmod(input, 0o755)
        } else if isURL, let installed = executor.installedPath {
            // Assume installer dropped a script we can reuse
            let candidate = (installed as NSString).appendingPathComponent("install.sh")
            if FileManager.default.fileExists(atPath: candidate) {
                resolvedScript = candidate
                _ = chmod(candidate, 0o755)
            }
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        if let resolved = resolvedScript {
            p.arguments = [resolved]
        } else {
            p.arguments = ["-lc", input]
        }
        var env = ProcessInfo.processInfo.environment
        env["ACTION"] = "inject"
        env["EXECUTOR_INSTALL_DIR"] = executor.installedPath ?? ""
        env["INSTANCE_INDEX"] = String(instanceIndex)
        env["ROBLOX_CLONES_DIR"] = clonesDir
        p.environment = env
        do { try p.run(); p.waitUntilExit() } catch { /* ignore */ }
    }
    
    func updateDefaultLaunchSettings(_ launchSettings: LaunchSettings) {
        settings.defaultLaunchSettings = launchSettings
        saveSettings()
    }
    
    // MARK: - Reset and Restore
    
    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
    }
    
    func resetSection(_ section: SettingsSection) {
        let defaultSettings = AppSettings()
        
        switch section {
        case .appearance:
            settings.theme = defaultSettings.theme
            settings.accentColor = defaultSettings.accentColor
            settings.enableAnimations = defaultSettings.enableAnimations
        case .behavior:
            settings.enableNotifications = defaultSettings.enableNotifications
            settings.autoLaunchOnStartup = defaultSettings.autoLaunchOnStartup
            settings.maxSimultaneousLaunches = defaultSettings.maxSimultaneousLaunches
            settings.windowBehavior = defaultSettings.windowBehavior
        case .audio:
            settings.enableSoundEffects = defaultSettings.enableSoundEffects
            settings.enableHapticFeedback = defaultSettings.enableHapticFeedback
        case .security:
            settings.encryptionEnabled = defaultSettings.encryptionEnabled
            settings.autoBackup = defaultSettings.autoBackup
            settings.backupInterval = defaultSettings.backupInterval
        case .advanced:
            settings.dataStoragePath = defaultSettings.dataStoragePath
            settings.language = defaultSettings.language
            settings.defaultLaunchSettings = defaultSettings.defaultLaunchSettings
        }
        
        saveSettings()
    }
    
    // MARK: - Import/Export
    
    func exportSettings() throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings_export_\(Date().timeIntervalSince1970)")
            .appendingPathExtension("json")
        
        try storage.save(settings, to: tempURL.lastPathComponent, encrypted: false)
        return tempURL
    }
    
    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let importedSettings = try JSONDecoder().decode(AppSettings.self, from: data)
        settings = importedSettings
        saveSettings()
    }
    
    // MARK: - Auto Launch Management
    
    private func enableAutoLaunch() {
        let fm = FileManager.default
        let plistDir = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")
        let bundleId = Bundle.main.bundleIdentifier ?? "com.robloxaccountmanager.app"
        let plistPath = (plistDir as NSString).appendingPathComponent("\(bundleId).plist")
        try? fm.createDirectory(atPath: plistDir, withIntermediateDirectories: true)
        guard let appPath = Bundle.main.bundlePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        let program = "open"
        let args = ["-a", appPath]
        let dict: [String: Any] = [
            "Label": bundleId,
            "Program": program,
            "ProgramArguments": args,
            "RunAtLoad": true
        ]
        if let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0) {
            fm.createFile(atPath: plistPath, contents: data)
        }
        let launchctl = Process()
        launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        launchctl.arguments = ["load", plistPath]
        try? launchctl.run(); launchctl.waitUntilExit()
    }
    
    private func disableAutoLaunch() {
        let fm = FileManager.default
        let bundleId = Bundle.main.bundleIdentifier ?? "com.robloxaccountmanager.app"
        let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents/\(bundleId).plist")
        let launchctl = Process()
        launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        launchctl.arguments = ["unload", plistPath]
        try? launchctl.run(); launchctl.waitUntilExit()
        try? fm.removeItem(atPath: plistPath)
    }
    
    // MARK: - Validation
    
    func validateSettings() -> [String] {
        var errors: [String] = []
        
        if settings.maxSimultaneousLaunches < 1 || settings.maxSimultaneousLaunches > 10 {
            errors.append("Max simultaneous launches must be between 1 and 10")
        }
        
        if !settings.dataStoragePath.isEmpty && !FileManager.default.fileExists(atPath: settings.dataStoragePath) {
            errors.append("Data storage path does not exist")
        }
        
        return errors
    }
    
    // MARK: - Computed Properties
    
    var currentColorScheme: ColorScheme? {
        return settings.theme.colorScheme
    }
    
    var currentAccentColor: Color {
        return settings.accentColor.color
    }
    
    // Global palette colors
    var paletteBackground: Color {
        switch settings.uiPalette {
        case .system: return Color(NSColor.windowBackgroundColor)
        case .graphite: return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .midnight: return Color(red: 0.06, green: 0.08, blue: 0.12)
        case .ocean: return Color(red: 0.04, green: 0.15, blue: 0.22)
        case .forest: return Color(red: 0.06, green: 0.17, blue: 0.12)
        case .sunset: return Color(red: 0.16, green: 0.08, blue: 0.04)
        case .candy: return Color(red: 0.16, green: 0.06, blue: 0.12)
        }
    }
    
    var paletteSurface: Color {
        switch settings.uiPalette {
        case .system: return Color(NSColor.controlBackgroundColor)
        case .graphite: return Color(red: 0.16, green: 0.16, blue: 0.17)
        case .midnight: return Color(red: 0.09, green: 0.11, blue: 0.16)
        case .ocean: return Color(red: 0.07, green: 0.20, blue: 0.28)
        case .forest: return Color(red: 0.09, green: 0.23, blue: 0.17)
        case .sunset: return Color(red: 0.23, green: 0.12, blue: 0.08)
        case .candy: return Color(red: 0.25, green: 0.10, blue: 0.19)
        }
    }
    
    var paletteTextPrimary: Color {
        switch settings.uiPalette {
        case .system: return .primary
        default: return .white
        }
    }
    
    var paletteTextSecondary: Color {
        switch settings.uiPalette {
        case .system: return .secondary
        default: return Color.white.opacity(0.8)
        }
    }
    
    // MARK: - Gradient Presets (use ThemePalette as gradient selector) & Custom
    func gradientForPalette(_ preset: ThemePalette) -> LinearGradient {
        let colors: [Color]
        switch preset {
        case .system:
            colors = [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)]
        case .graphite:
            colors = [Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.04, green: 0.04, blue: 0.05)]
        case .midnight:
            colors = [Color(red: 0.09, green: 0.11, blue: 0.22), Color(red: 0.02, green: 0.03, blue: 0.08)]
        case .ocean:
            colors = [Color(red: 0.02, green: 0.45, blue: 0.65), Color(red: 0.01, green: 0.17, blue: 0.35)]
        case .forest:
            colors = [Color(red: 0.07, green: 0.40, blue: 0.20), Color(red: 0.02, green: 0.16, blue: 0.10)]
        case .sunset:
            colors = [Color(red: 0.95, green: 0.50, blue: 0.20), Color(red: 0.60, green: 0.10, blue: 0.30)]
        case .candy:
            colors = [Color(red: 0.95, green: 0.30, blue: 0.55), Color(red: 0.45, green: 0.15, blue: 0.85)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func colorFromHex(_ hex: String) -> Color {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return .gray }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let a: Double
        let r: Double
        let g: Double
        let b: Double
        if s.count == 8 {
            a = Double((rgb & 0xFF000000) >> 24) / 255.0
            r = Double((rgb & 0x00FF0000) >> 16) / 255.0
            g = Double((rgb & 0x0000FF00) >> 8) / 255.0
            b = Double(rgb & 0x000000FF) / 255.0
        } else {
            a = 1.0
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    private func gradientWithAngle(colors: [Color], degrees: Double) -> LinearGradient {
        // Map degrees to start/end points on unit square
        let radians = degrees * Double.pi / 180.0
        // Convert to vector
        let vx = cos(radians)
        let vy = sin(radians)
        // Map vector to start/end normalized points
        let start = UnitPoint(x: 0.5 - vx * 0.5, y: 0.5 - vy * 0.5)
        let end = UnitPoint(x: 0.5 + vx * 0.5, y: 0.5 + vy * 0.5)
        return LinearGradient(colors: colors, startPoint: start, endPoint: end)
    }
    
    var selectedGradient: LinearGradient {
        if settings.useCustomGradient {
            let c1 = colorFromHex(settings.customGradientStartHex)
            let c2 = colorFromHex(settings.customGradientEndHex)
            return gradientWithAngle(colors: [c1, c2], degrees: settings.customGradientAngleDegrees)
        } else {
            return gradientForPalette(settings.uiPalette)
        }
    }
    
    var animationDuration: Double {
        guard settings.enableAnimations else { return 0.0 }
        let base: Double
        switch settings.animationPreset {
        case .soft: base = 0.35
        case .balanced: base = 0.26
        case .snappy: base = 0.18
        }
        return settings.beautifulMode ? base * 1.15 : base
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        isLoading = true
        error = nil
        
        do {
            if storage.exists(fileName) {
                settings = try storage.load(AppSettings.self, from: fileName)
            }
        } catch {
            self.error = AppError.loadingFailed(error.localizedDescription)
            settings = AppSettings() // Fallback to defaults
        }
        
        isLoading = false
    }
    
    private func saveSettings() {
        do {
            try storage.save(settings, to: fileName)
        } catch {
            self.error = AppError.savingFailed(error.localizedDescription)
        }
    }

    // MARK: - Public API for MultiLauncher
    func applyAssignedExecutorsToClones(totalInstances: Int) {
        moveClonesToDesiredDir()
        var clonesDir = settings.robloxClonesDirectory
        if clonesDir.isEmpty { clonesDir = defaultClonesDirectory() }
        for idx in 1...max(1, totalInstances) {
            if let execId = settings.executorAssignmentsByInstance[idx],
               let exec = settings.executors.first(where: { $0.id == execId }) {
                runInjectionScript(executor: exec, instanceIndex: idx, clonesDir: clonesDir)
            }
        }
    }

    // MARK: - Clone Management
    func defaultClonesDirectory() -> String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("RobloxClones")
    }
    func opiumwareClonesDirectory() -> String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("Opiumware/Clones")
    }
    func macsploitClonesDirectory() -> String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("MacSploit/Clones")
    }
    func hydrogenClonesDirectory() -> String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("Hydrogen/Clones")
    }
    private func findExistingMacSploitBase() -> String? {
        let dir = macsploitClonesDirectory()
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
        // Prefer Roblox-MacSploit-1.app (MacSploit’s own naming), fall back to our naming
        if let name = items.first(where: { $0.hasPrefix("Roblox-MacSploit-") && $0.hasSuffix(".app") }) {
            return (dir as NSString).appendingPathComponent(name)
        }
        if let name = items.first(where: { $0.hasPrefix("macsploit-roblox-") && $0.hasSuffix(".app") }) {
            return (dir as NSString).appendingPathComponent(name)
        }
        return nil
    }
    private func findExistingOpiumwareBase() -> String? {
        let dir = opiumwareClonesDirectory()
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
        if let name = items.first(where: { $0.hasPrefix("Roblox-Opiumware-") && $0.hasSuffix(".app") }) {
            return (dir as NSString).appendingPathComponent(name)
        }
        if let name = items.first(where: { $0.hasPrefix("roblox-opiumware-") && $0.hasSuffix(".app") }) {
            return (dir as NSString).appendingPathComponent(name)
        }
        return nil
    }
    private func findExistingHydrogenBase() -> String? {
        let dir = hydrogenClonesDirectory()
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
        if let name = items.first(where: { $0.hasPrefix("hydrogen-roblox-") && $0.hasSuffix(".app") }) {
            return (dir as NSString).appendingPathComponent(name)
        }
        if let name = items.first(where: { $0.hasPrefix("Roblox-Hydrogen-") && $0.hasSuffix(".app") }) {
            return (dir as NSString).appendingPathComponent(name)
        }
        return nil
    }
    private func opiumwareBaseAppPath() -> String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("Opiumware/Base/Roblox.app")
    }
    private func macsploitBaseAppPath() -> String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("MacSploit/Base/Roblox.app")
    }
    private func hydrogenBaseAppPath() -> String {
        return (NSHomeDirectory() as NSString).appendingPathComponent("Hydrogen/Base/Roblox.app")
    }
    private func ensureParentDirExists(for path: String) {
        let parent = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
    }

    private func locateMacSploitDylibCandidate() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/Applications/Roblox.app/Contents/MacOS/macsploit.dylib",
            (macsploitBaseAppPath() as NSString).appendingPathComponent("Contents/MacOS/macsploit.dylib"),
            ((findExistingMacSploitBase() ?? "") as NSString).appendingPathComponent("Contents/MacOS/macsploit.dylib")
        ].filter { !$0.isEmpty }
        for c in candidates { if fm.fileExists(atPath: c) { return c } }
        return nil
    }
    private func locateHydrogenDylibCandidate() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/Applications/Roblox.app/Contents/MacOS/hydrogen.dylib",
            (hydrogenBaseAppPath() as NSString).appendingPathComponent("Contents/MacOS/hydrogen.dylib"),
            ((findExistingHydrogenBase() ?? "") as NSString).appendingPathComponent("Contents/MacOS/hydrogen.dylib")
        ].filter { !$0.isEmpty }
        for c in candidates { if fm.fileExists(atPath: c) { return c } }
        return nil
    }

    private func patchMacSploitForClone(at destApp: String) {
        let fm = FileManager.default
        guard let dylibSrc = locateMacSploitDylibCandidate() else {
            print("[Clones][MacSploit] macsploit.dylib not found anywhere; skipping dylib copy/patch")
            return
        }
        let macOSDir = (destApp as NSString).appendingPathComponent("Contents/MacOS")
        let dylibDst = (macOSDir as NSString).appendingPathComponent("macsploit.dylib")
        try? fm.removeItem(atPath: dylibDst)
        do { try fm.copyItem(atPath: dylibSrc, toPath: dylibDst) } catch {
            print("[Clones][MacSploit] copy failed: \(error.localizedDescription)")
        }
        // Ensure Resources/content/custom directory exists for MacSploit writes
        let contentCustom = (destApp as NSString).appendingPathComponent("Contents/Resources/content/custom")
        try? fm.createDirectory(atPath: contentCustom, withIntermediateDirectories: true)
        // Rewrite load command in RobloxPlayer to point to @executable_path/macsploit.dylib
        let robloxPlayer = (macOSDir as NSString).appendingPathComponent("RobloxPlayer")
        let installTool = "/usr/bin/install_name_tool"
        let changeFrom = "/Applications/Roblox.app/Contents/MacOS/macsploit.dylib"
        let runChange = Process(); runChange.executableURL = URL(fileURLWithPath: installTool); runChange.arguments = ["-change", changeFrom, "@executable_path/macsploit.dylib", robloxPlayer]
        let out = Pipe(); let err = Pipe(); runChange.standardOutput = out; runChange.standardError = err
        do { try runChange.run(); runChange.waitUntilExit() } catch { print("[Clones][MacSploit] install_name_tool failed: \(error.localizedDescription)") }
        if runChange.terminationStatus != 0 {
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("[Clones][MacSploit] install_name_tool exit=\(runChange.terminationStatus) err=\n\(e)")
        }
        // Re-sign app after patch
        let cs = Process(); cs.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); cs.arguments = ["--force", "--deep", "--sign", "-", "--timestamp=none", destApp]
        try? cs.run(); cs.waitUntilExit()
    }

    private func patchHydrogenForClone(at destApp: String) {
        let fm = FileManager.default
        guard let dylibSrc = locateHydrogenDylibCandidate() else {
            print("[Clones][Hydrogen] hydrogen.dylib not found; skipping dylib copy/patch")
            return
        }
        let macOSDir = (destApp as NSString).appendingPathComponent("Contents/MacOS")
        let dylibDst = (macOSDir as NSString).appendingPathComponent("hydrogen.dylib")
        try? fm.removeItem(atPath: dylibDst)
        do { try fm.copyItem(atPath: dylibSrc, toPath: dylibDst) } catch { print("[Clones][Hydrogen] copy failed: \(error.localizedDescription)") }
        let robloxPlayer = (macOSDir as NSString).appendingPathComponent("RobloxPlayer")
        let installTool = "/usr/bin/install_name_tool"
        let changeFrom = "/Applications/Roblox.app/Contents/MacOS/hydrogen.dylib"
        let runChange = Process(); runChange.executableURL = URL(fileURLWithPath: installTool); runChange.arguments = ["-change", changeFrom, "@executable_path/hydrogen.dylib", robloxPlayer]
        let err = Pipe(); runChange.standardError = err
        try? runChange.run(); runChange.waitUntilExit()
        if runChange.terminationStatus != 0 {
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("[Clones][Hydrogen] install_name_tool exit=\(runChange.terminationStatus) err=\n\(e)")
        }
        let cs = Process(); cs.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); cs.arguments = ["--force", "--deep", "--sign", "-", "--timestamp=none", destApp]
        try? cs.run(); cs.waitUntilExit()
    }

    // Create/update ~/Applications/Roblox.app -> <clone> symlink for MacSploit path expectations
    func ensureHomeApplicationsSymlink(to appPath: String) {
        let fm = FileManager.default
        let homeApps = (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
        let link = (homeApps as NSString).appendingPathComponent("Roblox.app")
        try? fm.createDirectory(atPath: homeApps, withIntermediateDirectories: true)
        // Use ln -sfn to atomically repoint the symlink without touching real folders
        let ln = Process(); ln.executableURL = URL(fileURLWithPath: "/bin/ln"); ln.arguments = ["-sfn", appPath, link]
        let out = Pipe(); let err = Pipe(); ln.standardOutput = out; ln.standardError = err
        do { try ln.run(); ln.waitUntilExit() } catch { print("[Clones][MacSploit] symlink failed: \(error.localizedDescription)") }
        if ln.terminationStatus != 0 {
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("[Clones][MacSploit] ln exit=\(ln.terminationStatus) err=\n\(e)")
        } else {
            print("[Clones][MacSploit] Linked ~/Applications/Roblox.app -> \(appPath)")
        }
    }
    
    // Prepare N Roblox clones that bypass single instance detection
    func prepareMultiInstanceClones(desiredCount: Int, flavor: RobloxFlavor = .clean) {
        let fm = FileManager.default
        let count = max(1, min(10, desiredCount))
        func run(_ executable: String, _ args: [String], label: String) {
            let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = args
            let out = Pipe(); let err = Pipe(); p.standardOutput = out; p.standardError = err
            print("[Clones][Run] \(executable) \(args.joined(separator: " "))  -> \(label)")
            do { try p.run(); p.waitUntilExit() } catch { print("[Clones][Run][\(label)] failed to start: \(error.localizedDescription)"); return }
            let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            print("[Clones][Run][\(label)] exit=\(p.terminationStatus) out=\n\(o)\nerr=\n\(e)")
        }
        // Pick source Roblox based on flavor, using flavor-specific snapshots to avoid cross-injection
        var source: String = ""
        switch flavor {
        case .clean:
            let cand = ["/Applications/Roblox.app", (NSHomeDirectory() as NSString).appendingPathComponent("Applications/Roblox.app")]
            guard let s = cand.first(where: { fm.fileExists(atPath: $0) }) else {
                print("[Clones] Roblox.app not found in /Applications or ~/Applications")
                return
            }
            source = s
        case .opiumware:
            let base = opiumwareBaseAppPath()
            // Marker files for Opiumware-modified install
            let marker1 = "Contents/Resources/libSystem.dylib"
            let marker2 = "Contents/Resources/Patcher"
            let baseHasMarkers = fm.fileExists(atPath: (base as NSString).appendingPathComponent(marker1)) || fm.fileExists(atPath: (base as NSString).appendingPathComponent(marker2))
            if fm.fileExists(atPath: base), baseHasMarkers {
                source = base
            } else {
                // Try to derive from an existing Opiumware clone if the main app is clean
                if let existing = findExistingOpiumwareBase() {
                    ensureParentDirExists(for: base)
                    run("/usr/bin/ditto", ["--noextattr", "--norsrc", existing, base], label: "snapshot-opiumware-from-clone")
                    source = base
                } else {
                    let appPath = "/Applications/Roblox.app"
                    guard fm.fileExists(atPath: appPath) else {
                        print("[Clones] Opiumware base missing and /Applications/Roblox.app not found")
                        return
                    }
                    // Validate /Applications has Opiumware markers; otherwise abort to avoid cross-flavor clones
                    let appsHasMarkers = fm.fileExists(atPath: (appPath as NSString).appendingPathComponent(marker1)) || fm.fileExists(atPath: (appPath as NSString).appendingPathComponent(marker2))
                    guard appsHasMarkers else {
                        print("[Clones] Opiumware not detected in /Applications/Roblox.app and no Opiumware clones present. Run installer, then Finalize.")
                        return
                    }
                    ensureParentDirExists(for: base)
                    run("/usr/bin/ditto", ["--noextattr", "--norsrc", appPath, base], label: "snapshot-opiumware-base")
                    source = base
                }
            }
        case .macsploit:
            let base = macsploitBaseAppPath()
            // Marker for MacSploit-modified install
            let msMarker = "Contents/MacOS/macsploit.dylib"
            let baseHasMarker = fm.fileExists(atPath: (base as NSString).appendingPathComponent(msMarker))
            if fm.fileExists(atPath: base), baseHasMarker {
                source = base
            } else {
                // Try to derive from an existing MacSploit clone (e.g., Roblox-MacSploit-1.app)
                if let existing = findExistingMacSploitBase() {
                    ensureParentDirExists(for: base)
                    run("/usr/bin/ditto", ["--noextattr", "--norsrc", existing, base], label: "snapshot-macsploit-from-clone")
                    source = base
                } else {
                    let appPath = "/Applications/Roblox.app"
                    guard fm.fileExists(atPath: appPath) else {
                        print("[Clones] MacSploit base missing and /Applications/Roblox.app not found")
                        return
                    }
                    // Validate /Applications has MacSploit marker; otherwise abort
                    guard fm.fileExists(atPath: (appPath as NSString).appendingPathComponent(msMarker)) else {
                        print("[Clones] MacSploit not detected in /Applications/Roblox.app and no MacSploit clones present. Run installer, then Finalize.")
                        return
                    }
                    ensureParentDirExists(for: base)
                    run("/usr/bin/ditto", ["--noextattr", "--norsrc", appPath, base], label: "snapshot-macsploit-base")
                    source = base
                }
            }
        case .hydrogen:
            let base = hydrogenBaseAppPath()
            let marker = "Contents/MacOS/hydrogen.dylib"
            let baseHasMarker = fm.fileExists(atPath: (base as NSString).appendingPathComponent(marker))
            if fm.fileExists(atPath: base), baseHasMarker {
                source = base
            } else if let existing = findExistingHydrogenBase() {
                ensureParentDirExists(for: base)
                run("/usr/bin/ditto", ["--noextattr", "--norsrc", existing, base], label: "snapshot-hydrogen-from-clone")
                source = base
            } else {
                let appPath = "/Applications/Roblox.app"
                guard fm.fileExists(atPath: appPath) else { print("[Clones] Hydrogen base missing and /Applications/Roblox.app not found"); return }
                guard fm.fileExists(atPath: (appPath as NSString).appendingPathComponent(marker)) else {
                    print("[Clones] Hydrogen not detected in /Applications/Roblox.app and no Hydrogen clones present. Run installer, then Finalize.")
                    return
                }
                ensureParentDirExists(for: base)
                run("/usr/bin/ditto", ["--noextattr", "--norsrc", appPath, base], label: "snapshot-hydrogen-base")
                source = base
            }
        }
        var clonesDir: String
        switch flavor {
        case .clean:
            clonesDir = settings.robloxClonesDirectory.isEmpty ? defaultClonesDirectory() : settings.robloxClonesDirectory
        case .opiumware:
            clonesDir = opiumwareClonesDirectory()
        case .macsploit:
            clonesDir = macsploitClonesDirectory()
        case .hydrogen:
            clonesDir = hydrogenClonesDirectory()
        }
        try? fm.createDirectory(atPath: clonesDir, withIntermediateDirectories: true)

        for i in 1...count {
            let prefix: String
            switch flavor {
            case .clean: prefix = "Roblox-"
            case .opiumware: prefix = "roblox-opiumware-"
            case .macsploit: prefix = "macsploit-roblox-"
            case .hydrogen: prefix = "hydrogen-roblox-"
            }
            let name = "\(prefix)\(i).app"
            let dest = (clonesDir as NSString).appendingPathComponent(name)
            // Copy app: ditto --noextattr --norsrc to preserve layout but drop extended attrs
            if fm.fileExists(atPath: dest) { try? fm.removeItem(atPath: dest) }
            print("[Clones] Copying base -> \(dest)")
            run("/usr/bin/ditto", ["--noextattr", "--norsrc", source, dest], label: "copy-clone-\(i)")
            // Remove quarantine
            run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", dest], label: "xattr-\(i)")
            // Rewrite Info.plist: identifiers, names, remove URL handlers, allow multi-instance
            rewriteInfoPlist(forAppAt: dest, instanceIndex: i, flavor: flavor)
            // Ensure executable exists and remains named RobloxPlayer
            let exe = (dest as NSString).appendingPathComponent("Contents/MacOS/RobloxPlayer")
            _ = chmod(exe, 0o755)
            // If MacSploit flavor, ensure dylib is local and update load command to @executable_path
            if flavor == .macsploit { patchMacSploitForClone(at: dest) }
            if flavor == .hydrogen { patchHydrogenForClone(at: dest) }
            // Deep sign
            run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", "--timestamp=none", dest], label: "codesign-\(i)")
        }
    }

    private func rewriteInfoPlist(forAppAt appPath: String, instanceIndex: Int, flavor: RobloxFlavor) {
        let plistURL = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL) else { return }
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard var dict = (try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any]) else { return }
        let baseId = "com.roblox.client"
        let suffix: String
        let displayPrefix: String
        switch flavor {
        case .clean:
            suffix = ".instance\(instanceIndex)"
            displayPrefix = "Roblox-"
        case .opiumware:
            suffix = ".opiumware.instance\(instanceIndex)"
            displayPrefix = "roblox-opiumware-"
        case .macsploit:
            suffix = ".macsploit.instance\(instanceIndex)"
            displayPrefix = "macsploit-roblox-"
        case .hydrogen:
            suffix = ".hydrogen.instance\(instanceIndex)"
            displayPrefix = "hydrogen-roblox-"
        }
        dict["CFBundleIdentifier"] = baseId + suffix
        dict["CFBundleName"] = "\(displayPrefix)\(instanceIndex)"
        dict["CFBundleDisplayName"] = "\(displayPrefix)\(instanceIndex)"
        dict["CFBundleExecutable"] = (dict["CFBundleExecutable"] as? String) ?? "RobloxPlayer"
        dict["LSMultipleInstancesProhibited"] = false
        dict.removeValue(forKey: "CFBundleURLTypes")
        // Ensure NSAppleEventsUsageDescription for GURL events (safety)
        if dict["NSAppleEventsUsageDescription"] == nil {
            dict["NSAppleEventsUsageDescription"] = "Allows this app to receive links for launching Roblox sessions."
        }
        if let newData = try? PropertyListSerialization.data(fromPropertyList: dict, format: format, options: 0) {
            try? newData.write(to: plistURL)
        }
    }
    func moveClonesToDesiredDir() {
        let fm = FileManager.default
        var dest = settings.robloxClonesDirectory
        if dest.isEmpty { dest = defaultClonesDirectory() }
        try? fm.createDirectory(atPath: dest, withIntermediateDirectories: true)
        // Search common locations
        let homes = [NSHomeDirectory(), (NSHomeDirectory() as NSString).appendingPathComponent("Applications"), "/Applications"]
        for base in homes {
            guard let items = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for name in items where name.hasPrefix("Roblox-") && name.hasSuffix(".app") {
                let src = (base as NSString).appendingPathComponent(name)
                let target = (dest as NSString).appendingPathComponent(name)
                if fm.fileExists(atPath: target) {
                    // If exists, overwrite
                    try? fm.removeItem(atPath: target)
                }
                do {
                    try fm.moveItem(atPath: src, toPath: target)
                    // Ensure not quarantined and signed
                    let x = Process(); x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr"); x.arguments = ["-dr", "com.apple.quarantine", target]; try? x.run(); x.waitUntilExit()
                    let cs = Process(); cs.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); cs.arguments = ["--force", "--deep", "--sign", "-", "--timestamp=none", target]; try? cs.run(); cs.waitUntilExit()
                } catch {
                    print("[Clones] Move failed for \(src): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Reinstall Clean Clones (No Hacks)
    func reinstallCleanClones(desiredCount: Int) {
        let fm = FileManager.default
        let dir = settings.robloxClonesDirectory.isEmpty ? defaultClonesDirectory() : settings.robloxClonesDirectory
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        if let items = try? fm.contentsOfDirectory(atPath: dir) {
            for name in items where name.hasPrefix("Roblox-") && name.hasSuffix(".app") {
                let path = (dir as NSString).appendingPathComponent(name)
                do { try fm.removeItem(atPath: path); print("[Clones][Clean] Removed \(path)") } catch {
                    print("[Clones][Clean] Remove failed for \(path): \(error.localizedDescription)")
                }
            }
        }
        let count = max(1, min(10, desiredCount))
        prepareMultiInstanceClones(desiredCount: count, flavor: .clean)
    }

    // Install clean Roblox to /Applications and then (on main actor) rebuild clean clones in the "good" directory
    func installCleanRobloxAndPrepare(desiredCount: Int) {
        Task.detached { [weak self] in
            guard let self else { return }
            // Reuse async download/install logic from installCleanRoblox
            let fm = FileManager.default
            let apps = "/Applications/Roblox.app"
            if fm.fileExists(atPath: apps) { try? fm.removeItem(atPath: apps) }
            let versionURL = URL(string: "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer")!
            var upload: String?
            do {
                let (verData, _) = try await URLSession.shared.data(from: versionURL)
                if let json = try JSONSerialization.jsonObject(with: verData) as? [String: Any] {
                    upload = (json["clientVersionUpload"] as? String) ?? ((json["clientVersionUploads"] as? [[String: Any]])?.first?["clientVersionUpload"] as? String)
                }
            } catch {
                print("[CleanInstall] Version fetch failed: \(error.localizedDescription)")
            }
            guard let upload else { print("[CleanInstall] Failed to resolve version"); return }
            let zipURL = URL(string: "https://setup.rbxcdn.com/mac/\(upload)-RobloxPlayer.zip")!
            let tmpZip = (NSTemporaryDirectory() as NSString).appendingPathComponent("RobloxPlayer.zip")
            do {
                let (zipData, _) = try await URLSession.shared.data(from: zipURL)
                try zipData.write(to: URL(fileURLWithPath: tmpZip))
            } catch {
                print("[CleanInstall] Download failed: \(error.localizedDescription)")
                return
            }
            let unzip = Process(); unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); unzip.arguments = ["-o", "-q", tmpZip, "-d", NSTemporaryDirectory()]
            try? unzip.run(); unzip.waitUntilExit()
            let tmpApp = (NSTemporaryDirectory() as NSString).appendingPathComponent("RobloxPlayer.app")
            guard fm.fileExists(atPath: tmpApp) else { print("[CleanInstall] Unzip missing RobloxPlayer.app"); return }
            do { try fm.moveItem(atPath: tmpApp, toPath: apps) } catch {
                let ditto = Process(); ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); ditto.arguments = [tmpApp, apps]
                try? ditto.run(); ditto.waitUntilExit()
            }
            let x = Process(); x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr"); x.arguments = ["-dr", "com.apple.quarantine", apps]; try? x.run(); x.waitUntilExit()
            let cs = Process(); cs.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); cs.arguments = ["--force", "--deep", "--sign", "-", "--timestamp=none", apps]; try? cs.run(); cs.waitUntilExit()
            print("[CleanInstall] Installed clean Roblox to /Applications/Roblox.app")
            // Now, back on main actor, rebuild clean clones in the good directory and count requested
            await MainActor.run {
                self.reinstallCleanClones(desiredCount: desiredCount)
            }
        }
    }

    // MARK: - Monitor /Applications for Roblox changes and trigger re-injection
    private var appsMonitor: DispatchSourceFileSystemObject?
    func startApplicationsMonitor() {
        let path = "/Applications"
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .attrib, .delete, .rename], queue: DispatchQueue.global(qos: .background))
        src.setEventHandler { [weak self] in
            guard let self = self else { return }
            // If Roblox.app changed or new Roblox-*.app appeared, re-apply assignments
            DispatchQueue.main.async {
                let count = self.detectCloneCount()
                self.applyAssignedExecutorsToClones(totalInstances: max(1, count))
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        appsMonitor = src
    }
    private func detectCloneCount() -> Int {
        let fm = FileManager.default
        var dir = settings.robloxClonesDirectory
        if dir.isEmpty { dir = defaultClonesDirectory() }
        var count = 0
        if let items = try? fm.contentsOfDirectory(atPath: dir) {
            count += items.filter { $0.hasPrefix("Roblox-") && $0.hasSuffix(".app") }.count
        }
        if let items = try? fm.contentsOfDirectory(atPath: opiumwareClonesDirectory()) {
            count += items.filter { $0.hasPrefix("roblox-opiumware-") && $0.hasSuffix(".app") }.count
        }
        if let items = try? fm.contentsOfDirectory(atPath: macsploitClonesDirectory()) {
            count += items.filter { $0.hasPrefix("macsploit-roblox-") && $0.hasSuffix(".app") }.count
        }
        if let items = try? fm.contentsOfDirectory(atPath: hydrogenClonesDirectory()) {
            count += items.filter { $0.hasPrefix("hydrogen-roblox-") && $0.hasSuffix(".app") }.count
        }
        return count
    }

    // MARK: - Auto-detect installed flavor
    func autoDetectedFlavor() -> RobloxFlavor {
        let fm = FileManager.default
        let apps = "/Applications/Roblox.app"
        if fm.fileExists(atPath: (apps as NSString).appendingPathComponent("Contents/MacOS/macsploit.dylib")) { return .macsploit }
        if fm.fileExists(atPath: (apps as NSString).appendingPathComponent("Contents/Resources/Patcher")) || fm.fileExists(atPath: (apps as NSString).appendingPathComponent("Contents/Resources/libSystem.dylib")) { return .opiumware }
        if fm.fileExists(atPath: (apps as NSString).appendingPathComponent("Contents/MacOS/hydrogen.dylib")) { return .hydrogen }
        return .clean
    }

    // MARK: - Clean Roblox installer (unpatched)
    func installCleanRoblox() {
        // Run network and disk operations off the main thread to avoid UI stalls
        Task.detached {
            let fm = FileManager.default
            let apps = "/Applications/Roblox.app"
            if fm.fileExists(atPath: apps) { try? fm.removeItem(atPath: apps) }
            // Fetch latest version JSON asynchronously
            let versionURL = URL(string: "https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer")!
            var upload: String?
            do {
                let (verData, _) = try await URLSession.shared.data(from: versionURL)
                if let json = try JSONSerialization.jsonObject(with: verData) as? [String: Any] {
                    upload = (json["clientVersionUpload"] as? String) ?? ((json["clientVersionUploads"] as? [[String: Any]])?.first?["clientVersionUpload"] as? String)
                }
            } catch {
                print("[CleanInstall] Version fetch failed: \(error.localizedDescription)")
            }
            guard let upload else { print("[CleanInstall] Failed to resolve version"); return }
            // Download zip asynchronously
            let zipURL = URL(string: "https://setup.rbxcdn.com/mac/\(upload)-RobloxPlayer.zip")!
            let tmpZip = (NSTemporaryDirectory() as NSString).appendingPathComponent("RobloxPlayer.zip")
            do {
                let (zipData, _) = try await URLSession.shared.data(from: zipURL)
                try zipData.write(to: URL(fileURLWithPath: tmpZip))
            } catch {
                print("[CleanInstall] Download failed: \(error.localizedDescription)")
                return
            }
            // Unzip
            let unzip = Process(); unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); unzip.arguments = ["-o", "-q", tmpZip, "-d", NSTemporaryDirectory()]
            try? unzip.run(); unzip.waitUntilExit()
            let tmpApp = (NSTemporaryDirectory() as NSString).appendingPathComponent("RobloxPlayer.app")
            guard fm.fileExists(atPath: tmpApp) else { print("[CleanInstall] Unzip missing RobloxPlayer.app"); return }
            // Move to /Applications/Roblox.app
            do { try fm.moveItem(atPath: tmpApp, toPath: apps) } catch {
                let ditto = Process(); ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto"); ditto.arguments = [tmpApp, apps]
                try? ditto.run(); ditto.waitUntilExit()
            }
            // Unquarantine and sign
            let x = Process(); x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr"); x.arguments = ["-dr", "com.apple.quarantine", apps]; try? x.run(); x.waitUntilExit()
            let cs = Process(); cs.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); cs.arguments = ["--force", "--deep", "--sign", "-", "--timestamp=none", apps]; try? cs.run(); cs.waitUntilExit()
            print("[CleanInstall] Installed clean Roblox to /Applications/Roblox.app")
        }
    }
}

// MARK: - Supporting Types

enum SettingsSection: String, CaseIterable {
    case appearance = "appearance"
    case behavior = "behavior"
    case audio = "audio"
    case security = "security"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .appearance: return "Appearance"
        case .behavior: return "Behavior"
        case .audio: return "Audio & Feedback"
        case .security: return "Security & Privacy"
        case .advanced: return "Advanced"
        }
    }
    
    var iconName: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .behavior: return "gearshape.fill"
        case .audio: return "speaker.wave.3.fill"
        case .security: return "lock.shield.fill"
        case .advanced: return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Settings Helpers

extension SettingsManager {
    func getAnimationDuration(for animationType: AnimationType) -> Double {
        guard settings.enableAnimations else { return 0.0 }
        
        switch animationType {
        case .quick:
            switch settings.animationPreset { case .soft: return 0.22; case .balanced: return 0.16; case .snappy: return 0.12 }
        case .normal:
            switch settings.animationPreset { case .soft: return 0.35; case .balanced: return 0.26; case .snappy: return 0.18 }
        case .slow:
            switch settings.animationPreset { case .soft: return 0.55; case .balanced: return 0.42; case .snappy: return 0.3 }
        case .spring:
            switch settings.animationPreset { case .soft: return 0.7; case .balanced: return 0.55; case .snappy: return 0.42 }
        }
    }
    
    func getSpringAnimation(for animationType: AnimationType) -> Animation? {
        guard settings.enableAnimations else { return nil }
        
        func scale(_ value: Double) -> Double { settings.beautifulMode ? value * 1.15 : value }
        func damp(_ value: Double) -> Double { settings.beautifulMode ? max(0.75, value - 0.06) : value }
        switch animationType {
        case .quick:
            switch settings.animationPreset { case .soft: return .interpolatingSpring(stiffness: 120, damping: 14); case .balanced: return .interpolatingSpring(stiffness: 140, damping: 12); case .snappy: return .interpolatingSpring(stiffness: 180, damping: 10) }
        case .normal:
            if settings.beautifulMode {
                return .interpolatingSpring(stiffness: 110, damping: 13)
            } else {
                switch settings.animationPreset { case .soft: return .spring(response: scale(0.55), dampingFraction: damp(0.85)); case .balanced: return .spring(response: scale(0.42), dampingFraction: damp(0.82)); case .snappy: return .spring(response: scale(0.3), dampingFraction: damp(0.88)) }
            }
        case .slow:
            if settings.beautifulMode {
                return .interpolatingSpring(stiffness: 80, damping: 12)
            } else {
                switch settings.animationPreset { case .soft: return .spring(response: scale(0.85), dampingFraction: damp(0.86)); case .balanced: return .spring(response: scale(0.7), dampingFraction: damp(0.84)); case .snappy: return .spring(response: scale(0.55), dampingFraction: damp(0.9)) }
            }
        case .spring:
            if settings.beautifulMode {
                return .interpolatingSpring(stiffness: 95, damping: 11)
            } else {
                switch settings.animationPreset { case .soft: return .spring(response: scale(0.7), dampingFraction: damp(0.86)); case .balanced: return .spring(response: scale(0.55), dampingFraction: damp(0.84)); case .snappy: return .spring(response: scale(0.42), dampingFraction: damp(0.92)) }
            }
        }
    }
}

enum AnimationType {
    case quick
    case normal
    case slow
    case spring
}
