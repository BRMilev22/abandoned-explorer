import SwiftUI

struct SmartBottomPanel: View {
    @EnvironmentObject var dataManager: DataManager
    let currentLocationName: String
    let currentZoomLevel: Double
    let onGroupsPressed: () -> Void
    let onCreateGroupPressed: () -> Void
    let onJoinGroupPressed: (String) -> Void
    
    @State private var isExpanded = true
    @State private var dragOffset: CGFloat = 0
    @State private var inviteCode: String = ""
    @State private var isCreateButtonPulsating = false
    
    // Zoom thresholds for panel visibility
    private let expandedZoomThreshold: Double = 14.0
    private let hiddenZoomThreshold: Double = 13.0
    
    // Check if user has any groups
    private var hasGroups: Bool {
        !dataManager.userGroups.isEmpty
    }
    
    // Get the primary group (first one or selected one)
    private var primaryGroup: Group? {
        if let selectedGroup = dataManager.selectedGroup {
            return selectedGroup
        }
        return dataManager.userGroups.first
    }
    
    // Determine if panel should be expanded based on zoom level
    private var shouldExpand: Bool {
        currentZoomLevel >= expandedZoomThreshold
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Pull indicator when collapsed
            if !isExpanded {
                Button(action: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }) {
                    VStack(spacing: 4) {
                        // Pull up indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.6))
                            .frame(width: 40, height: 4)
                        
                        // Chevron up icon
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        Color.black.opacity(0.3)
                            .blur(radius: 10)
                    )
                    .background(.ultraThinMaterial)
                }
            }
            
            // Main panel content
            if isExpanded {
                if hasGroups {
                    // Show group preview when user has groups
                    groupPreviewContent
                } else {
                    // Show group options when user has no groups
                    groupOptionsContent
                }
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow downward dragging when expanded
                    if isExpanded && value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if value.translation.height > 50 && isExpanded {
                            // Hide panel if dragged down significantly
                            isExpanded = false
                        }
                        dragOffset = 0
                    }
                }
        )
        .onChange(of: currentZoomLevel) { newZoomLevel in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                if newZoomLevel >= expandedZoomThreshold && !isExpanded {
                    // Show panel when zooming in to street level
                    isExpanded = true
                } else if newZoomLevel <= hiddenZoomThreshold && isExpanded {
                    // Hide panel when zooming out to state/country level
                    isExpanded = false
                }
            }
        }
        .onAppear {
            // Set initial state based on zoom level
            isExpanded = shouldExpand
        }
    }
    
    // MARK: - Group Options Content (when user has no groups)
    @ViewBuilder
    private var groupOptionsContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Create Group Button (Left side with pulsating effect)
                Button(action: onCreateGroupPressed) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: "7289da"))
                        
                        Text("Create a\nGroup")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                            .background(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color(hex: "7289da").opacity(isCreateButtonPulsating ? 0.8 : 0.3),
                                lineWidth: isCreateButtonPulsating ? 2 : 1
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isCreateButtonPulsating ? 1.05 : 0.98)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isCreateButtonPulsating)
                .onAppear {
                    isCreateButtonPulsating = true
                }
                
                // Invite Code Input (Right side)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invite Code")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        TextField("Enter code", text: $inviteCode)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.2))
                                    .background(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        
                        Button(action: {
                            if !inviteCode.isEmpty {
                                onJoinGroupPressed(inviteCode)
                                inviteCode = ""
                            }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(inviteCode.isEmpty ? .gray : Color(hex: "7289da"))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(inviteCode.isEmpty)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    // MARK: - Group Preview Content (when user has groups)
    @ViewBuilder
    private var groupPreviewContent: some View {
        if let group = primaryGroup {
            VStack(spacing: 12) {
                // Top row: Avatar and tab buttons
                HStack(spacing: 12) {
                    // User Avatar with online indicator
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text("T")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        // Green online indicator
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .offset(x: 15, y: 15)
                    }
                    
                    // Tab navigation
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Group", "Members", "Chat", "Locations", "Settings"], id: \.self) { tab in
                                Button(action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()
                                    onGroupsPressed()
                                }) {
                                    Text(tab)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(tab == "Group" ? .white : .gray)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(tab == "Group" ? Color(hex: "7289da").opacity(0.8) : Color.white.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                        .background(.ultraThinMaterial)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(tab == "Group" ? 1.05 : 1.0)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                // Info row
                HStack(spacing: 16) {
                    // Region info
                    infoCard(icon: "globe", title: "Region", value: group.region, color: Color(hex: "7289da"))
                    
                    // Points info
                    infoCard(icon: "star.fill", title: "Points", value: "\(group.points)", color: .yellow)
                    
                    // Team Code info
                    infoCard(icon: "link.circle.fill", title: "Team Code", value: group.inviteCode, color: Color(hex: "7289da"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Color.black.opacity(0.3)
                    .blur(radius: 10)
            )
            .background(.ultraThinMaterial)
        }
    }
    
    private func infoCard(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .background(.ultraThinMaterial)
    }
}

// MARK: - Group Tab Button Component
struct GroupTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(hex: "7289da") : Color.gray.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color(hex: "7289da") : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            SmartBottomPanel(
                currentLocationName: "Sofia, Bulgaria",
                currentZoomLevel: 15.0,
                onGroupsPressed: {},
                onCreateGroupPressed: {},
                onJoinGroupPressed: { _ in }
            )
            .environmentObject({
                let dm = DataManager()
                // Simulate no groups for preview
                dm.userGroups = []
                return dm
            }())
        }
    }
} 