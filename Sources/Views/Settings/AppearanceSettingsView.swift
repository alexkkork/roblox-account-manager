import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var startColor: Color = .blue
    @State private var endColor: Color = .purple
    @State private var angleDeg: Double = 45
    
    var body: some View {
        VStack(spacing: 24) {
            // Theme Selection
            SettingsGroup(title: "Theme", icon: "paintbrush.fill") {
                VStack(spacing: 16) {
                    HStack {
                        Text("Choose your preferred theme")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            ThemeButton(
                                theme: theme,
                                isSelected: settingsManager.settings.theme == theme
                            ) {
                                settingsManager.updateTheme(theme)
                            }
                        }
                    }
                }
            }
            
            // Gradient (global UI background)
            SettingsGroup(title: "Background Gradient", icon: "square.fill.on.square.fill") {
                VStack(spacing: 16) {
                    HStack {
                        Text("Preset")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("Palette", selection: .init(
                            get: { settingsManager.settings.uiPalette },
                            set: { settingsManager.settings.uiPalette = $0 }
                        )) {
                            ForEach(ThemePalette.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 160)
                    }
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(settingsManager.selectedGradient)
                        .frame(height: 80)
                        .overlay(
                            HStack(spacing: 10) {
                                Circle().fill(settingsManager.currentAccentColor).frame(width: 18, height: 18)
                                Text("Preview")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Gradient")
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 14)
                        )

                    Divider()

                    // Custom gradient toggle + controls
                    Toggle("Use custom gradient", isOn: .init(
                        get: { settingsManager.settings.useCustomGradient },
                        set: { settingsManager.settings.useCustomGradient = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))

                    if settingsManager.settings.useCustomGradient {
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Start Color")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    ColorPicker("", selection: $startColor, supportsOpacity: true)
                                        .labelsHidden()
                                        .frame(width: 44, height: 28)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("End Color")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    ColorPicker("", selection: $endColor, supportsOpacity: true)
                                        .labelsHidden()
                                        .frame(width: 44, height: 28)
                                }
                                Button("Swap") {
                                    let a = startColor
                                    startColor = endColor
                                    endColor = a
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                                AngleWheel(angle: $angleDeg)
                                    .frame(width: 120, height: 120)
                            }
                            HStack(spacing: 12) {
                                Text("Angle")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Slider(value: $angleDeg, in: 0...360)
                                    .frame(width: 280)
                                Text("\(Int(angleDeg))°")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 40, alignment: .trailing)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                // Sync local color wheel states with settings and write back on changes
                .onAppear {
                    startColor = colorFromHex(settingsManager.settings.customGradientStartHex)
                    endColor = colorFromHex(settingsManager.settings.customGradientEndHex)
                    angleDeg = settingsManager.settings.customGradientAngleDegrees
                }
                .onChange(of: settingsManager.settings.useCustomGradient) { _ in
                    startColor = colorFromHex(settingsManager.settings.customGradientStartHex)
                    endColor = colorFromHex(settingsManager.settings.customGradientEndHex)
                    angleDeg = settingsManager.settings.customGradientAngleDegrees
                }
                .onChange(of: startColor) { _ in
                    settingsManager.settings.customGradientStartHex = hexFromColor(startColor)
                }
                .onChange(of: endColor) { _ in
                    settingsManager.settings.customGradientEndHex = hexFromColor(endColor)
                }
                .onChange(of: angleDeg) { newVal in
                    settingsManager.settings.customGradientAngleDegrees = newVal
                }
            }
            
            // Accent Color Selection
            SettingsGroup(title: "Accent Color", icon: "paintpalette.fill") {
                VStack(spacing: 16) {
                    HStack {
                        Text("Choose your accent color")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(AccentColorOption.allCases, id: \.self) { color in
                            AccentColorButton(
                                colorOption: color,
                                isSelected: settingsManager.settings.accentColor == color
                            ) {
                                settingsManager.updateAccentColor(color)
                            }
                        }
                    }
                }
            }
            
            // Animation Settings
            SettingsGroup(title: "Animations", icon: "sparkles") {
                VStack(spacing: 16) {
                    Toggle("Enable animations", isOn: .init(
                        get: { settingsManager.settings.enableAnimations },
                        set: { _ in settingsManager.toggleAnimations() }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                    Toggle("Beautiful Mode (enhanced visuals)", isOn: .init(
                        get: { settingsManager.settings.beautifulMode },
                        set: { _ in settingsManager.toggleBeautifulMode() }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: settingsManager.currentAccentColor))
                    HStack {
                        Text("Preset")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Picker("Preset", selection: .init(
                            get: { settingsManager.settings.animationPreset },
                            set: { settingsManager.settings.animationPreset = $0 }
                        )) {
                            ForEach(AnimationPreset.allCases, id: \.self) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When enabled, the app will use smooth animations and transitions.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("Disabling animations may improve performance on older systems.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // Window controls removed (non-functional)
            
            // Preview
            SettingsGroup(title: "Preview", icon: "eye.fill") {
                VStack(spacing: 16) {
                    Text("Preview of current theme and accent color")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    AppearancePreview()
                }
            }
        }
    }
}

// MARK: - Helpers (hex <-> Color) + Angle Wheel
private func colorFromHex(_ hex: String) -> Color {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    if s.hasPrefix("#") { s.removeFirst() }
    var rgb: UInt64 = 0
    guard Scanner(string: s).scanHexInt64(&rgb) else { return .gray }
    let a, r, g, b: Double
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

private func hexFromColor(_ color: Color) -> String {
    guard let cg = color.cgColor else { return "#FFFFFF" }
    let comps = cg.components ?? [1,1,1,1]
    let r, g, b, a: CGFloat
    if comps.count >= 4 {
        r = comps[0]; g = comps[1]; b = comps[2]; a = comps[3]
    } else if comps.count == 2 {
        r = comps[0]; g = comps[0]; b = comps[0]; a = comps[1]
    } else {
        r = 1; g = 1; b = 1; a = 1
    }
    let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255)), ai = Int(round(a * 255))
    if ai < 255 { return String(format: "#%02X%02X%02X%02X", ai, ri, gi, bi) }
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}

private func syncLocalFromSettings() {
}

struct AngleWheel: View {
    @Binding var angle: Double
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s = min(w, h)
            let r = s/2 - 12
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                let theta = CGFloat(angle) * .pi / 180
                let cx = w/2; let cy = h/2
                let hx = cx + cos(theta) * r
                let hy = cy + sin(theta) * r
                Path { p in
                    p.move(to: CGPoint(x: cx, y: cy))
                    p.addLine(to: CGPoint(x: hx, y: hy))
                }
                .stroke(Color.secondary.opacity(0.6), lineWidth: 2)
                Circle()
                    .fill(Color.primary)
                    .frame(width: 10, height: 10)
                    .position(x: hx, y: hy)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - w/2
                        let dy = value.location.y - h/2
                        var deg = Double(atan2(dy, dx) * 180 / .pi)
                        if deg < 0 { deg += 360 }
                        angle = deg
                    }
            )
        }
    }
}

// MARK: - Theme Button

struct ThemeButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themePreviewColor)
                        .frame(height: 60)
                    
                    Image(systemName: theme.iconName)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(theme.iconColor)
                }
                
                Text(theme.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? settingsManager.currentAccentColor : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? settingsManager.currentAccentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? settingsManager.currentAccentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(settingsManager.getSpringAnimation(for: .quick), value: isSelected)
    }
    
    private var themePreviewColor: Color {
        switch theme {
        case .light: return Color.white
        case .dark: return Color.black
        case .system: return Color.secondary.opacity(0.3)
        }
    }
}

// MARK: - Accent Color Button

struct AccentColorButton: View {
    let colorOption: AccentColorOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(colorOption.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    )
                
                Text(colorOption.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Appearance Preview

struct AppearancePreview: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 12) {
            // Mock window
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 12, height: 12)
                        Circle().fill(.yellow).frame(width: 12, height: 12)
                        Circle().fill(.green).frame(width: 12, height: 12)
                    }
                    
                    Spacer()
                    
                    Text("Roblox Account Manager")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
                
                // Content area
                VStack(spacing: 12) {
                    HStack {
                        Text("Sample Content")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Button") {}
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    
                    HStack {
                        Text("This is how your theme looks")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    HStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(settingsManager.currentAccentColor)
                            .frame(width: 60, height: 20)
                        
                        Text("Accent Color")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .frame(maxWidth: 300)
    }
}

// MARK: - AppTheme Extension

extension AppTheme {
    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "gear"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .light: return .orange
        case .dark: return .blue
        case .system: return .secondary
        }
    }
}

#Preview {
    AppearanceSettingsView()
        .environmentObject(SettingsManager())
        .padding()
}
