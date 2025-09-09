import SwiftUI

struct GameFiltersView: View {
    @Binding var criteria: GameFilterCriteria
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var tempCriteria: GameFilterCriteria
    
    init(criteria: Binding<GameFilterCriteria>) {
        self._criteria = criteria
        self._tempCriteria = State(initialValue: criteria.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Genre filter
                    genreFilterView
                    
                    // Rating filter
                    ratingFilterView
                    
                    // Player count filter
                    playerCountFilterView
                    
                    // Options
                    optionsView
                    
                    // Sort options
                    sortOptionsView
                    
                    // Reset button
                    resetButtonView
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Game Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        criteria = tempCriteria
                        dismiss()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(settingsManager.currentAccentColor)
            
            Text("Game Filters")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text("Customize which games are displayed")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var genreFilterView: some View {
        FilterSection(title: "Genre", icon: "gamecontroller.fill") {
            VStack(spacing: 12) {
                HStack {
                    Text("Select Genre:")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    if tempCriteria.genre != nil {
                        Button("Clear") {
                            tempCriteria.genre = nil
                        }
                        .font(.system(size: 14))
                        .foregroundColor(settingsManager.currentAccentColor)
                    }
                }
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 120), spacing: 12)
                ], spacing: 12) {
                    ForEach(GameGenre.allCases, id: \.self) { genre in
                        GenreButton(
                            genre: genre,
                            isSelected: tempCriteria.genre == genre
                        ) {
                            tempCriteria.genre = tempCriteria.genre == genre ? nil : genre
                        }
                    }
                }
            }
        }
    }
    
    private var ratingFilterView: some View {
        FilterSection(title: "Minimum Rating", icon: "star.fill") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Rating:")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Text(tempCriteria.minRating != nil ? String(format: "%.1f+", tempCriteria.minRating!) : "Any")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(settingsManager.currentAccentColor)
                }
                
                HStack(spacing: 16) {
                    ForEach([0.0, 1.0, 2.0, 3.0, 4.0, 4.5], id: \.self) { rating in
                        Button(action: {
                            tempCriteria.minRating = tempCriteria.minRating == rating ? nil : rating
                        }) {
                            HStack(spacing: 4) {
                                ForEach(0..<Int(rating), id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                }
                                if rating.truncatingRemainder(dividingBy: 1) != 0 {
                                    Image(systemName: "star.leadinghalf.filled")
                                        .font(.system(size: 12))
                                        .foregroundColor(.yellow)
                                }
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(tempCriteria.minRating == rating ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(tempCriteria.minRating == rating ? settingsManager.currentAccentColor : Color(NSColor.controlBackgroundColor))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private var playerCountFilterView: some View {
        FilterSection(title: "Maximum Players", icon: "person.2.fill") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Max Players:")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Spacer()
                    
                    Text(tempCriteria.maxPlayers != nil ? "\(tempCriteria.maxPlayers!) or fewer" : "Any")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(settingsManager.currentAccentColor)
                }
                
                HStack(spacing: 12) {
                    ForEach([10, 20, 50, 100], id: \.self) { count in
                        Button("\(count)") {
                            tempCriteria.maxPlayers = tempCriteria.maxPlayers == count ? nil : count
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(tempCriteria.maxPlayers == count ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(tempCriteria.maxPlayers == count ? settingsManager.currentAccentColor : Color(NSColor.controlBackgroundColor))
                        )
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    private var optionsView: some View {
        FilterSection(title: "Options", icon: "checkmark.circle.fill") {
            VStack(spacing: 16) {
                Toggle("Verified games only", isOn: $tempCriteria.verifiedOnly)
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                
                Text("Show only games that have been verified by Roblox")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var sortOptionsView: some View {
        FilterSection(title: "Sort By", icon: "arrow.up.arrow.down") {
            VStack(spacing: 12) {
                ForEach(GameSortType.allCases, id: \.self) { sortType in
                    Button(action: {
                        tempCriteria.sortType = sortType
                    }) {
                        HStack {
                            Text(sortType.displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(tempCriteria.sortType == sortType ? settingsManager.currentAccentColor : .primary)
                            
                            Spacer()
                            
                            if tempCriteria.sortType == sortType {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(settingsManager.currentAccentColor)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tempCriteria.sortType == sortType ? settingsManager.currentAccentColor.opacity(0.1) : Color.clear)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private var resetButtonView: some View {
        Button("Reset All Filters") {
            tempCriteria = GameFilterCriteria()
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.red)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red, lineWidth: 1)
        )
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Section

struct FilterSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Genre Button

struct GenreButton: View {
    let genre: GameGenre
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: genre.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : settingsManager.currentAccentColor)
                
                Text(genre.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? settingsManager.currentAccentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? settingsManager.currentAccentColor : settingsManager.currentAccentColor.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
    }
}

#Preview {
    GameFiltersView(criteria: .constant(GameFilterCriteria()))
        .environmentObject(SettingsManager())
}
