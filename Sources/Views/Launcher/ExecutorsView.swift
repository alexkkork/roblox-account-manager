import SwiftUI

struct ExecutorsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @State private var newExecutorName = ""
    @State private var newExecutorURLString = ""
    @State private var showingChooseInstallDir = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                installDirectory
                addExecutor
                listExecutors
                instanceAssignments
                popularExecutors
                analyzeScripts
                testLaunch
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 30)
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 24, weight: .medium))
                    Text("Executors")
                        .font(.system(size: 28, weight: .bold))
                }
                Text("Install, manage, and assign executors to robloxN instances")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var installDirectory: some View {
        SettingsGroup(title: "Install Directory", icon: "folder") {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Where executors will be installed and indexed")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                TextField("/path/to/executors", text: .init(
                    get: { settingsManager.settings.executorsInstallDirectory },
                    set: { settingsManager.settings.executorsInstallDirectory = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minWidth: 420)
                Button("Choose…") { showingChooseInstallDir = true }
                Button("Use App Support (Recommended)") { settingsManager.settings.executorsInstallDirectory = settingsManager.defaultExecutorsDirectory() }
            }
        }
        .fileImporter(isPresented: $showingChooseInstallDir, allowedContentTypes: [.folder]) { result in
            if case let .success(url) = result { settingsManager.settings.executorsInstallDirectory = url.path }
        }
    }
    
    private var addExecutor: some View {
        SettingsGroup(title: "Add Executor", icon: "plus.circle.fill") {
            HStack(spacing: 8) {
                TextField("Name", text: $newExecutorName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Install link or script path", text: $newExecutorURLString)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Add") { addExecutorAction() }
                    .disabled(newExecutorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newExecutorURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private var listExecutors: some View {
        SettingsGroup(title: "Installed Executors", icon: "list.bullet") {
            VStack(spacing: 10) {
                ForEach(settingsManager.settings.executors) { exec in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exec.name)
                                .font(.system(size: 14, weight: .semibold))
                            if !exec.installURLString.isEmpty {
                                Text(exec.installURLString)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            if let path = exec.installedPath, !path.isEmpty {
                                Text(path)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Button("Install/Update") { runInstallInTerminal(exec.installURLString) }
                            .buttonStyle(.bordered)
                        Button("Remove", role: .destructive) { settingsManager.removeExecutor(exec) }
                            .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            }
        }
    }
    
    private var instanceAssignments: some View {
        SettingsGroup(title: "Instance Assignments", icon: "square.stack.3d.down.forward.fill") {
            HStack(spacing: 12) {
                ForEach(Array(1..<(max(settingsManager.settings.maxSimultaneousLaunches, 2) + 1)), id: \.self) { idx in
                    VStack {
                        Text("roblox\\(idx)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Picker("", selection: .init(
                            get: { settingsManager.settings.executorAssignmentsByInstance[idx] },
                            set: { settingsManager.settings.executorAssignmentsByInstance[idx] = $0 }
                        )) {
                            Text("Normal").tag(Optional<UUID>.none)
                            ForEach(settingsManager.settings.executors) { exec in
                                Text(exec.name).tag(Optional(exec.id))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 180)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            }
        }
    }

    private var popularExecutors: some View {
        SettingsGroup(title: "Popular Executors", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Install a known executor with one click. These run in Terminal with admin rights.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button("Install Opiumware") { installOpiumware() }
                        .buttonStyle(.borderedProminent)
                    Button("Install MacSploit") { installMacSploit() }
                        .buttonStyle(.bordered)
                    Button("Install Hydrogen-M") { installHydrogen() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Analyze and Patch
    @State private var scriptText: String = ""
    @State private var analyzedURLs: [String] = []
    @State private var analyzedDylibs: [String] = []
    @State private var analyzedTargets: [String] = []
    @State private var chosenDylibPath: String = ""
    @State private var instancesDir: String = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = base.appendingPathComponent("RobloxAccountManager/RobloxInstances", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.path
    }()

    private var analyzeScripts: some View {
        SettingsGroup(title: "Analyze & Patch Dylib", icon: "wrench.and.screwdriver") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Paste an installer script (Opiumware, MacSploit, Hydrogen). We'll extract dylib URLs and destinations, then you can patch the dylib into clones under \(instancesDir).")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextEditor(text: $scriptText)
                    .font(.system(size: 11).monospaced())
                    .frame(minHeight: 140)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack(spacing: 10) {
                    Button("Analyze") {
                        let res = settingsManager.analyzeInstallerScript(scriptText)
                        self.analyzedURLs = res.dylibURLs
                        self.analyzedDylibs = res.dylibNames
                        self.analyzedTargets = res.targetPaths
                    }
                    .buttonStyle(.bordered)
                    TextField("Instances dir", text: $instancesDir)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                if !analyzedURLs.isEmpty || !analyzedDylibs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if !analyzedURLs.isEmpty {
                            Text("Found URLs:").font(.system(size: 12, weight: .semibold))
                            ForEach(analyzedURLs, id: \.self) { u in Text(u).font(.system(size: 11)).foregroundColor(.secondary) }
                        }
                        if !analyzedDylibs.isEmpty {
                            Text("Dylibs:").font(.system(size: 12, weight: .semibold))
                            ForEach(analyzedDylibs, id: \.self) { d in Text(d).font(.system(size: 11)).foregroundColor(.secondary) }
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Downloaded dylib path (absolute)", text: $chosenDylibPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Patch into Instances") {
                        guard !chosenDylibPath.isEmpty else { return }
                        settingsManager.patchDylibToInstances(dylibAbsolutePath: chosenDylibPath, instancesDir: instancesDir, maxInstances: 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - Test Launch UI
    private var testLaunch: some View {
        SettingsGroup(title: "Test Launch", icon: "play.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quickly test a launch using your current clones and executor assignments.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Picker("Account", selection: .init(
                        get: { accountManager.selectedAccount?.id ?? accountManager.accounts.first?.id },
                        set: { id in
                            if let id, let acc = accountManager.accounts.first(where: { $0.id == id }) {
                                accountManager.selectedAccount = acc
                            }
                        }
                    )) {
                        ForEach(accountManager.accounts) { acc in
                            Text(acc.displayName).tag(Optional(acc.id))
                        }
                    }
                    .frame(width: 220)

                    Picker("Game", selection: .init(
                        get: { gameManager.selectedGame?.id ?? gameManager.games.first?.id },
                        set: { gid in
                            if let gid, let g = (gameManager.games + gameManager.searchResults).first(where: { $0.id == gid }) {
                                gameManager.selectGame(g)
                            }
                        }
                    )) {
                        ForEach(gameManager.games) { g in
                            Text(g.name).tag(Optional(g.id))
                        }
                    }
                    .frame(width: 280)

                    Button("Launch Test") {
                        if let acc = accountManager.selectedAccount, let game = gameManager.selectedGame {
                            multiLauncher.launchGame(account: acc, game: game)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(accountManager.selectedAccount == nil || gameManager.selectedGame == nil)
                }
            }
        }
    }
    
    private func addExecutorAction() {
        let name = newExecutorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = newExecutorURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !url.isEmpty else { return }
        settingsManager.addExecutor(name: name, installURLString: url)
        newExecutorName = ""
        newExecutorURLString = ""
    }
    
    // MARK: - Terminal helper
    private func runInstallInTerminal(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        var dest = settingsManager.settings.executorsInstallDirectory
        if dest.isEmpty { dest = settingsManager.defaultExecutorsDirectory() }
        try? FileManager.default.createDirectory(atPath: dest, withIntermediateDirectories: true)
        let clones = settingsManager.settings.robloxClonesDirectory.isEmpty ? settingsManager.defaultClonesDirectory() : settingsManager.settings.robloxClonesDirectory
        let export = "cd $HOME; export ACTION=install; export EXECUTOR_INSTALL_DIR=\(dest.quoted()); export ROBLOX_CLONES_DIR=\(clones.quoted());"
        let preflight = "mkdir -p \"$HOME/Opiumware/modules/Server\" \"$HOME/Opiumware/modules/luau-lsp\";"
        let postflight = "; set -e; :"
        let fullCmd = export + " " + preflight + " " + trimmed + " " + postflight
        let shell = "sudo /bin/zsh -lc \(fullCmd.quoted())"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let osa = "tell application \"Terminal\" to do script \"\(shell.escapedForOSA())\""
        p.arguments = ["-e", osa]
        try? p.run()
    }
	
	private func installOpiumware() {
		let script = "set -e; json=$(curl -s \"https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer\"); version=$(echo \"$json\" | grep -o '\\"clientVersionUpload\\":\\"[^\\"]*' | grep -o '[^\\"]*$'); pgrep -x RobloxPlayer >/dev/null && pkill -9 RobloxPlayer || true; sudo rm -rf /Applications/Roblox.app /Applications/Opiumware.app; WORK=\"$TMPDIR/ow-$$\"; rm -rf \"$WORK\"; mkdir -p \"$WORK\"; cd \"$WORK\"; curl -L \"https://setup.rbxcdn.com/mac/$version-RobloxPlayer.zip\" -o RobloxPlayer.zip; unzip -o -q RobloxPlayer.zip; sudo mv ./RobloxPlayer.app /Applications/Roblox.app; sudo xattr -cr /Applications/Roblox.app; curl -L \"https://f3a5dqxez3.ufs.sh/f/ijk9xZzvhn3r6NqJEBxeyLZ0nksTlQH7jtXAS9W6uJpmiwFv\" -o libSystem.zip; unzip -o -q libSystem.zip; sudo mv ./libSystem.dylib /Applications/Roblox.app/Contents/Resources/libSystem.dylib; curl -L \"https://f3a5dqxez3.ufs.sh/f/ijk9xZzvhn3rRLgqCJ6EwKLWJ0ADYbMyxP8H6QpokZ7F1aiu\" -o modules.zip; unzip -o -q modules.zip; chmod +x ./Resources/Patcher || true; sudo ./Resources/Patcher /Applications/Roblox.app/Contents/Resources/libSystem.dylib /Applications/Roblox.app/Contents/MacOS/libmimalloc.3.dylib --strip-codesig --all-yes || true; if [ -f /Applications/Roblox.app/Contents/MacOS/libmimalloc.3.dylib_patched ]; then sudo mv /Applications/Roblox.app/Contents/MacOS/libmimalloc.3.dylib_patched /Applications/Roblox.app/Contents/MacOS/libmimalloc.3.dylib; fi; sudo codesign --force --deep --sign - /Applications/Roblox.app; curl -L \"https://f3a5dqxez3.ufs.sh/f/ijk9xZzvhn3rD2IKHTvR2QK1iVgakWyNDMPsXvcA9eG8xIHn\" -o OpiumwareUI.zip; unzip -o -q OpiumwareUI.zip; mkdir -p \"$HOME/Opiumware/workspace\" \"$HOME/Opiumware/autoexec\" \"$HOME/Opiumware/themes\" \"$HOME/Opiumware/modules/Server\" \"$HOME/Opiumware/modules/luau-lsp\"; rm -rf \"$HOME/Opiumware/modules/latest.json\" \"$HOME/Opiumware/modules/luau-lsp\" \"$HOME/Opiumware/modules/Server\"; mkdir -p \"$HOME/Opiumware/modules/Server\" \"$HOME/Opiumware/modules/luau-lsp\"; mv -f Resources/Server \"$HOME/Opiumware/modules/Server/server\" || true; mv -f Resources/luau-lsp \"$HOME/Opiumware/modules/luau-lsp/luau-lsp\" || true; if [ -d ./Opiumware.app ]; then sudo mv ./Opiumware.app /Applications/Opiumware.app; fi; sudo rm -rf /Applications/Roblox.app/Contents/MacOS/RobloxPlayerInstaller.app || true;"
		runRawScriptInTerminal(script)
	}
	
	private func installMacSploit() {
		let script = "set -e; WORK=\"$TMPDIR/ms-$$\"; rm -rf \"$WORK\"; mkdir -p \"$WORK\"; cd \"$WORK\"; curl -s \"https://git.raptor.fun/main/jq-macos-amd64\" -o ./jq; chmod +x ./jq; curl -s \"https://clientsettingscdn.roblox.com/v2/client-version/MacPlayer\" -o rv.json; RVER=$(cat rv.json | ./jq -r .clientVersionUpload); curl -L \"http://setup.rbxcdn.com/mac/$RVER-RobloxPlayer.zip\" -o RobloxPlayer.zip; unzip -o -q RobloxPlayer.zip; sudo rm -rf /Applications/Roblox.app; sudo mv ./RobloxPlayer.app /Applications/Roblox.app; curl -L \"https://git.raptor.fun/main/macsploit.zip\" -o MacSploit.zip; unzip -o -q MacSploit.zip; curl -L \"https://git.raptor.fun/main/macsploit.dylib\" -o macsploit.dylib; sudo mv macsploit.dylib /Applications/Roblox.app/Contents/MacOS/macsploit.dylib; INSD=\"$TMPDIR/insert-$$\"; curl -L \"https://git.raptor.fun/main/insert_dylib\" -o \"$INSD\"; chmod +x \"$INSD\"; sudo \"$INSD\" /Applications/Roblox.app/Contents/MacOS/macsploit.dylib /Applications/Roblox.app/Contents/MacOS/RobloxPlayer --strip-codesig --all-yes; sudo mv /Applications/Roblox.app/Contents/MacOS/RobloxPlayer_patched /Applications/Roblox.app/Contents/MacOS/RobloxPlayer; sudo rm -rf /Applications/Roblox.app/Contents/MacOS/RobloxPlayerInstaller.app; sudo rm -rf /Applications/MacSploit.app; sudo mv ./MacSploit.app /Applications/MacSploit.app;"
		runRawScriptInTerminal(script)
	}
	
	private func installHydrogen() {
		// Hydrogen is unique: fetches and runs a Rust installer with explicit URLs
		let hydrogenInstallerURL = "https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmt8OGDr546yzQVkLwJsKXF8Y7eoi1cUprDjC2"
		let hydrogenMURL = "https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjm6G06fL5Y9NPtXuqoZsSJebkQBGvjIy12HdFO"
		let robloxArm = "https://setup.rbxcdn.com/mac/arm64/version-1f7443723bfe4e74-RobloxPlayer.zip"
		let robloxX86 = "https://setup.rbxcdn.com/mac/version-1f7443723bfe4e74-RobloxPlayer.zip"
		let cmd = "INSTALLER=\"$TMPDIR/hydrogen_installer\"; curl -fsSL \"\(hydrogenInstallerURL)\" -o \"$INSTALLER\" && chmod +x \"$INSTALLER\" && \"$INSTALLER\" --hydrogen-url \"\(hydrogenMURL)\" --roblox-url-arm \"\(robloxArm)\" --roblox-url-x86 \"\(robloxX86)\" && rm -f \"$INSTALLER\""
		runRawScriptInTerminal(cmd)
	}
	
	private func runRawScriptInTerminal(_ script: String) {
		let shell = "sudo /bin/zsh -lc \(script.quoted())"
		let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
		let osa = "tell application \"Terminal\" to do script \"\(shell.escapedForOSA())\""
		p.arguments = ["-e", osa]
		try? p.run()
	}
}

private extension String {
    func quoted() -> String { return "\"" + self.replacingOccurrences(of: "\"", with: "\\\"") + "\"" }
    func escapedForOSA() -> String {
        var s = self
        s = s.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: "\"", with: "\\\"")
        s = s.replacingOccurrences(of: "\n", with: "\\n")
        return s
    }
}


