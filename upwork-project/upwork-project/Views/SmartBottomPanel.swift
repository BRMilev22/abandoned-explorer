import SwiftUI

struct SmartBottomPanel: View {
    @EnvironmentObject var dataManager: DataManager
    let currentLocationName: String
    let currentZoomLevel: Double
    let onGroupsPressed: () -> Void
    let onCreateGroupPressed: () -> Void
    let onJoinGroupPressed: (String) -> Void
    let hideNotifications: Bool // New parameter to hide notifications in feed view
    
    @State private var isExpanded = true
    @State private var dragOffset: CGFloat = 0
    @State private var inviteCode: String = ""
    @State private var isCreateButtonPulsating = false
    @State private var chasingAnimationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var chasingRotation: Double = 0
    @State private var buttonPulseScale: CGFloat = 1.0
    
    // Notification cycling state
    @State private var showingNotification = false
    @State private var currentNotificationType = 0 // 0 = users, 1 = locations
    @State private var notificationTimer: Timer?
    
    // Number of characters expected in the invite code
    private let codeLength: Int = 6
    
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
            // Notification appears above the panel (expanded or minimized)
            // Only show notifications when not in feed view
            if showingNotification && !hideNotifications {
                notificationView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false) // Don't interfere with panel interactions
                    .padding(.bottom, 16) // Space between notification and panel
            }
            
            // Pull indicator when collapsed
            if !isExpanded {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.1)) {
                        isExpanded = true
                    }
                }) {
                    VStack(spacing: 4) {
                        // Pull up indicator
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 40, height: 4)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        
                        // Chevron up icon
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.1)) {
                        if value.translation.height > 50 && isExpanded {
                            // Hide panel if dragged down significantly
                            isExpanded = false
                        }
                        dragOffset = 0
                    }
                }
        )
        .onChange(of: currentZoomLevel) { newZoomLevel in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.1)) {
                // Panel expansion logic
                if newZoomLevel >= hiddenZoomThreshold {
                    if !isExpanded {
                        isExpanded = true
                    }
                } else {
                    if isExpanded {
                        isExpanded = false
                    }
                }
                
                // Notification logic - independent of panel state
                // Show notifications for reasonable zoom levels (>= 10.0) and not in feed view
                if newZoomLevel >= 10.0 && !hideNotifications {
                    if !showingNotification {
                        startNotificationCycle()
                    }
                } else {
                    // Stop notifications at low zoom levels or when in feed view
                    stopNotificationCycle()
                }
            }
        }
        .onAppear {
            // Set initial panel state
            if currentZoomLevel >= hiddenZoomThreshold {
                isExpanded = true
            }
            
            // Start notifications for reasonable zoom levels and not in feed view
            if currentZoomLevel >= 10.0 && !hideNotifications {
                startNotificationCycle()
            }
        }
        .onDisappear {
            stopNotificationCycle()
        }
    }
    
    // MARK: - Notification View
    @ViewBuilder
    private var notificationView: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(currentNotificationType == 0 ? Color.green.opacity(0.2) : Color(hex: "7289da").opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: currentNotificationType == 0 ? "person.2.fill" : "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(currentNotificationType == 0 ? Color.green : Color(hex: "7289da"))
            }
            
            // Text content using real nearby statistics
            VStack(alignment: .leading, spacing: 2) {
                if currentNotificationType == 0 {
                    Text("\(dataManager.nearbyActiveUsersCount) other users")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("near you")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                } else {
                    Text("\(dataManager.nearbyLocationsCount) locations")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("around you")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.3))
                .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Group Options Content (when user has no groups)
    @ViewBuilder
    private var groupOptionsContent: some View {
        let panelHeight = UIScreen.main.bounds.height / 2.5 // Increased from /3 to provide more space for info popups
        
        VStack(spacing: 0) {
            // Top section with title and subtitle
            VStack(spacing: 8) {
                Text("Explore with friends")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                
                Text("Enter invite code or create your own group")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
            
            // Digit code input section
            VStack(spacing: 16) {
                // Code input with enhanced styling
                DigitCodeInputView(code: $inviteCode, maxDigits: codeLength)
                    .scaleEffect(inviteCode.isEmpty ? 1.0 : 1.02)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: inviteCode.isEmpty)
                
                // Join button - only visible when code is complete
                if inviteCode.count == codeLength {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        onJoinGroupPressed(inviteCode)
                        inviteCode = ""
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Join Group")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "7289da"),
                                            Color(hex: "5b6eae")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: Color(hex: "7289da").opacity(0.4), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(1.0)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: inviteCode.count == codeLength)
                }
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
            
            // Divider with "OR" text
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                
                Text("OR")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 16)
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
            
            // Create Group button with enhanced styling and animations
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onCreateGroupPressed()
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        // 3D layered circle background with enhanced glow
                        Circle()
                            .fill(Color(hex: "7289da").opacity(0.4))
                            .frame(width: 46, height: 46)
                            .shadow(color: Color(hex: "7289da").opacity(0.6), radius: 12, x: 0, y: 4)
                            .shadow(color: Color(hex: "7289da").opacity(0.3), radius: 20, x: 0, y: 8)
                        
                        Circle()
                            .fill(Color(hex: "7289da").opacity(0.3))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "7289da").opacity(0.8), lineWidth: 2)
                            )
                        
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color(hex: "7289da").opacity(0.8), radius: 4, x: 0, y: 2)
                            .scaleEffect(buttonPulseScale)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create a Group")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color(hex: "7289da").opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        Text("Start your own exploration team")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .scaleEffect(buttonPulseScale)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(buttonPulseScale)
            .background(
                ZStack {
                    // Base 3D layer - deepest shadow
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.6))
                        .offset(x: 0, y: 4)
                        .blur(radius: 8)
                    
                    // Main 3D background layer
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.25))
                        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                    
                    // 3D highlight gradient overlay
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.06),
                                    Color.clear,
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Inner shadow for depth
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.2),
                                    Color.clear,
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .blendMode(.overlay)
                }
            )
            .overlay(
                // Animated chasing border effect
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.clear,
                                Color.clear,
                                Color(hex: "7289da").opacity(0.3),
                                Color(hex: "5b6eae").opacity(0.8),
                                Color(hex: "7289da").opacity(1.0),
                                Color(hex: "8b9dc3").opacity(0.8),
                                Color(hex: "7289da").opacity(0.3),
                                Color.clear,
                                Color.clear,
                                Color.clear,
                                Color(hex: "7289da").opacity(0.2),
                                Color(hex: "5b6eae").opacity(0.6),
                                Color(hex: "7289da").opacity(0.8),
                                Color(hex: "8b9dc3").opacity(0.6),
                                Color(hex: "7289da").opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startAngle: .degrees(chasingRotation),
                            endAngle: .degrees(chasingRotation + 360)
                        ),
                        lineWidth: 3
                    )
                    .shadow(color: Color(hex: "7289da").opacity(0.4), radius: 8, x: 0, y: 0)
            )
            .overlay(
                // Additional glowing effect
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: "7289da").opacity(0.3), lineWidth: 1)
                    .blur(radius: 4)
                    .scaleEffect(buttonPulseScale * 1.02)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .onAppear {
                startButtonAnimations()
            }
            .onChange(of: isExpanded) { expanded in
                if expanded {
                    // Restart animations when panel expands
                    startButtonAnimations()
                } else {
                    // Stop animations when panel collapses
                    stopButtonAnimations()
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: panelHeight)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.black.opacity(0.2)) // Balanced transparency
                .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
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
                                                .fill(tab == "Group" ? Color(hex: "7289da").opacity(0.8) : Color.black.opacity(0.3))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 20)
                                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                                )
                                        )
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
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.2)) // Balanced transparency
                    .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Functions
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
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Notification Functions
    private func startNotificationCycle() {
        guard notificationTimer == nil else { return }
        
        notificationTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showingNotification = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentNotificationType = (currentNotificationType + 1) % 2
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingNotification = true
                }
            }
        }
        
        // Show first notification immediately
        withAnimation(.easeInOut(duration: 0.3)) {
            showingNotification = true
        }
    }
    
    private func stopNotificationCycle() {
        notificationTimer?.invalidate()
        notificationTimer = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            showingNotification = false
        }
    }
    
    // MARK: - Button Animation Helpers
    
    private func startButtonAnimations() {
        // Reset rotation to start from beginning
        chasingRotation = 0
        
        // Start chasing border animation
        withAnimation(
            .linear(duration: 3.0)
            .repeatForever(autoreverses: false)
        ) {
            chasingRotation = 360
        }
        
        // Start pulsating animation
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            buttonPulseScale = 1.12
        }
    }
    
    private func stopButtonAnimations() {
        // Stop animations by setting static values
        withAnimation(.easeOut(duration: 0.3)) {
            chasingRotation = 0
            buttonPulseScale = 1.0
        }
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

// MARK: - Digit Code Input Components

/// Root view that renders clay-styled digit boxes and hosts a hidden text field to capture keyboard input
struct DigitCodeInputView: View {
    @Binding var code: String
    let maxDigits: Int
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack {
            // Visible digit boxes (non-interactive so taps reach ZStack)
            HStack(spacing: 14) {
                let digits = Array(code)
                ForEach(0..<maxDigits, id: \.self) { index in
                    let char = index < digits.count ? String(digits[index]) : ""
                    ClayDigitBox(digit: char)
                }
            }
            .allowsHitTesting(false)

            // Hidden text field that actually receives the input
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .onChange(of: code) { newValue in
                    // Allow alphanumeric characters only, convert to uppercase, and limit length
                    let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                    if filtered != newValue || filtered.count > maxDigits {
                        code = String(filtered.prefix(maxDigits))
                    }
                }
                // Keep minimal footprint but ensure in layout for responder chain
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
        .contentShape(Rectangle()) // Make whole area tappable
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isFocused = true
            }
        }
    }
}

/// Single clay-styled digit box
struct ClayDigitBox: View {
    let digit: String
    @State private var isAnimating = false
    
    var body: some View {
        Text(digit)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            .frame(width: 48, height: 64)
            .background(
                ZStack {
                    // Base glassmorphism background
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                    
                    // Gradient overlay for depth
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(digit.isEmpty ? 0.05 : 0.15),
                                    Color.black.opacity(digit.isEmpty ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Border with subtle glow
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(digit.isEmpty ? 0.2 : 0.4),
                                    Color.white.opacity(digit.isEmpty ? 0.1 : 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: digit.isEmpty ? 1 : 1.5
                        )
                        .shadow(
                            color: Color(hex: "7289da").opacity(digit.isEmpty ? 0 : 0.3),
                            radius: digit.isEmpty ? 0 : 4,
                            x: 0,
                            y: 0
                        )
                }
            )
            .scaleEffect(digit.isEmpty ? 1.0 : 1.05)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: digit.isEmpty)
            .onAppear {
                // Subtle entrance animation
                withAnimation(.easeOut(duration: 0.6).delay(Double.random(in: 0...0.3))) {
                    isAnimating = true
                }
            }
            .opacity(isAnimating ? 1.0 : 0.0)
            .offset(y: isAnimating ? 0 : 10)
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
                onJoinGroupPressed: { _ in },
                hideNotifications: false
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