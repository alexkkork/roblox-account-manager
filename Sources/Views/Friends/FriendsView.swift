import SwiftUI
import Combine

struct FriendPresence: Identifiable {
    let id: Int
    let name: String
    let displayName: String
    var avatarURL: String
    var userPresenceType: Int
    var lastLocation: String
    var placeId: Int?
    var universeId: Int?
    var gameId: String?
    var lastOnline: String?
}

struct FriendsView: View {
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var gameManager: GameManager
    
    @State private var friends: [FriendPresence] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String = ""
    @State private var timerCancellable: AnyCancellable?
    
    var body: some View {
        VStack(spacing: 16) {
            header
            
            HStack {
                TextField("Search friends…", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 260)
                Spacer()
                Button(action: { Task { await refresh() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            
            if !errorText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text(errorText).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading friends…").foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredFriends) { f in
                            FriendRow(friend: f)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.vertical, 20)
        .onAppear { Task { await refresh() }; startAutoRefresh() }
        .onDisappear { timerCancellable?.cancel() }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill").font(.system(size: 22))
                    Text("Friends")
                        .font(.system(size: 28, weight: .bold))
                }
                Text("See who is online and what they’re playing")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
    }
    
    private var filteredFriends: [FriendPresence] {
        let base = friends
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        return base.filter { f in
            f.name.localizedCaseInsensitiveContains(searchText) || f.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func startAutoRefresh() {
        timerCancellable?.cancel()
        timerCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in Task { await refreshPresenceOnly() } }
    }
    
    private func currentCookie() -> String? {
        guard let acc = accountManager.selectedAccount ?? accountManager.accounts.first else { return nil }
        let c = acc.cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        return c.isEmpty ? nil : c
    }
    
    private func refreshPresenceOnly() async {
        guard let cookie = currentCookie(), !friends.isEmpty else { return }
        let ids = friends.map { $0.id }
        do {
            let pres = try await RobloxAPIService.shared.fetchPresence(userIds: ids, cookie: cookie)
            var map: [Int: RobloxAPIService.PresenceItem] = [:]
            for p in pres { map[p.userId] = p }
            for i in friends.indices {
                if let p = map[friends[i].id] {
                    friends[i].userPresenceType = p.userPresenceType
                    friends[i].lastLocation = p.lastLocation ?? ""
                    friends[i].placeId = p.placeId
                    friends[i].universeId = p.universeId
                    friends[i].gameId = p.gameId
                    friends[i].lastOnline = p.lastOnline
                }
            }
        } catch {
            errorText = "Presence refresh failed: \(error.localizedDescription)"
        }
    }
    
    private func refresh() async {
        isLoading = true
        errorText = ""
        defer { isLoading = false }
        guard let cookie = currentCookie() else { errorText = "No account selected or cookie missing"; return }
        do {
            // 1) Authenticated user id (also verifies cookie)
            let me = try await RobloxAPIService.shared.fetchUserInfo(from: cookie)
            accountManager.authenticatedUserId = me.id
            // 2) Friends list
            let basic = try await RobloxAPIService.shared.fetchFriends(of: me.id, cookie: cookie)
            let ids = basic.map { $0.id }
            // 3) Presence
            let presence = try await RobloxAPIService.shared.fetchPresence(userIds: ids, cookie: cookie)
            var presById: [Int: RobloxAPIService.PresenceItem] = [:]
            for p in presence { presById[p.userId] = p }
            // 4) Avatars
            let avatars = try await RobloxAPIService.shared.fetchAvatarHeadshots(userIds: ids)
            // 5) Build rows
            var rows: [FriendPresence] = []
            rows.reserveCapacity(basic.count)
            for f in basic {
                let p = presById[f.id]
                let avatar = avatars[f.id] ?? ""
                let row = FriendPresence(
                    id: f.id,
                    name: f.name,
                    displayName: f.displayName,
                    avatarURL: avatar,
                    userPresenceType: p?.userPresenceType ?? 0,
                    lastLocation: p?.lastLocation ?? "",
                    placeId: p?.placeId,
                    universeId: p?.universeId,
                    gameId: p?.gameId,
                    lastOnline: p?.lastOnline
                )
                rows.append(row)
            }
            // Sort: in-game first, then online, then offline
            friends = rows.sorted { a, b in
                func rank(_ t: Int) -> Int { t == 2 ? 0 : (t == 1 ? 1 : 2) }
                let ra = rank(a.userPresenceType), rb = rank(b.userPresenceType)
                if ra != rb { return ra < rb }
                return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct FriendRow: View {
    let friend: FriendPresence
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var presenceText: String {
        switch friend.userPresenceType {
        case 2:
            return friend.lastLocation.isEmpty ? "In-Game" : friend.lastLocation
        case 1:
            return friend.lastLocation.isEmpty ? "Online" : friend.lastLocation
        case 3:
            return "In Studio"
        default:
            return friend.lastOnline.map { "Last online: \($0)" } ?? "Offline"
        }
    }
    
    var presenceColor: Color {
        switch friend.userPresenceType {
        case 2: return .green
        case 1: return .blue
        case 3: return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: friend.avatarURL)) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.displayName).font(.system(size: 14, weight: .semibold)).foregroundColor(settingsManager.paletteTextPrimary)
                    if friend.displayName != friend.name {
                        Text("@\(friend.name)")
                            .font(.system(size: 12))
                            .foregroundColor(settingsManager.paletteTextSecondary)
                    }
                }
                Text(presenceText)
                    .font(.system(size: 12))
                    .foregroundColor(presenceColor)
            }
            Spacer()
            if friend.userPresenceType == 2, let placeId = friend.placeId {
                Button("Join") {
                    // Optional: Hook into launcher if desired using a default account
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(placeId == 0)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(settingsManager.paletteSurface.opacity(0.7))
        )
    }
}


