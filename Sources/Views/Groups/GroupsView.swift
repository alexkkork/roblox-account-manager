import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var groupManager: GroupManager
    @EnvironmentObject private var accountManager: AccountManager
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var multiLauncher: MultiLauncher
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var newGroupName: String = ""
    @State private var selectedGroupId: UUID?
    @State private var searchText: String = ""
    
    private var selectedGroup: AccountGroup? {
        groupManager.groups.first { $0.id == selectedGroupId }
    }
    
    private var filteredGroups: [AccountGroup] {
        guard !searchText.isEmpty else { return groupManager.groups }
        return groupManager.groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Groups list
            VStack(spacing: 12) {
                header
                searchBar
                List(selection: Binding(get: { selectedGroupId }, set: { id in
                    selectedGroupId = id
                })) {
                    ForEach(filteredGroups) { group in
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(settingsManager.currentAccentColor)
                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(group.accountIds.count) accounts")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .tag(group.id)
                    }
                    .onDelete { indexSet in
                        for index in indexSet { groupManager.delete(filteredGroups[index]) }
                    }
                }
            }
            .frame(width: 320)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Detail
            VStack(alignment: .leading, spacing: 16) {
                if let group = selectedGroup {
                    HStack {
                        Text(group.name)
                            .font(.system(size: 20, weight: .bold))
                        Spacer()
                        Button(action: { launch(group: group) }) {
                            Label("Launch Group", systemImage: "play.rectangle.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    
                    Text("Members")
                        .font(.system(size: 14, weight: .semibold))
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(members(for: group), id: \.id) { account in
                                HStack {
                                    Text(account.displayName)
                                        .font(.system(size: 14))
                                    Spacer()
                                    Button("Remove") {
                                        groupManager.removeAccount(account.id, from: group.id)
                                        selectedGroupId = group.id
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                            }
                        }
                    }
                    
                    Text("Add Accounts")
                        .font(.system(size: 14, weight: .semibold))
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(nonMembers(for: group), id: \.id) { account in
                                HStack {
                                    Text(account.displayName)
                                        .font(.system(size: 14))
                                    Spacer()
                                    Button("Add") {
                                        groupManager.addAccount(account.id, to: group.id)
                                        // reflect selection by id so it stays consistent
                                        selectedGroupId = group.id
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Select or create a group")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            TextField("New group name", text: $newGroupName)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            Button("Add") {
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let created = groupManager.create(name: name)
                newGroupName = ""
                selectedGroupId = created.id
            }
        }
        .padding(12)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search groups", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
        .padding(.horizontal, 12)
    }
    
    private func members(for group: AccountGroup) -> [Account] {
        accountManager.accounts.filter { group.accountIds.contains($0.id) }
    }
    private func nonMembers(for group: AccountGroup) -> [Account] {
        accountManager.accounts.filter { !group.accountIds.contains($0.id) }
    }
    private func launch(group: AccountGroup) {
        let accounts = members(for: group).filter { $0.isActive }
        if let game = gameManager.selectedGame ?? gameManager.games.first, !accounts.isEmpty {
            multiLauncher.launchGroup(accounts: accounts, game: game, staggerMs: 80)
        }
    }
}


