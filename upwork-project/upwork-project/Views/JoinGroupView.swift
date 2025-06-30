//
//  JoinGroupView.swift
//  upwork-project
//
//  Created by Boris Milev on 30.06.25.
//

import SwiftUI

struct JoinGroupView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var inviteCode = ""
    @State private var showingScanner = false
    
    let accentColor = Color(hex: "#7289da")
    
    var isFormValid: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        inviteCode.count == 8
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    headerView
                    
                    Spacer()
                    
                    // Main Content
                    VStack(spacing: 32) {
                        // Illustration
                        illustrationView
                        
                        // Title and Description
                        titleSection
                        
                        // Invite Code Input
                        inviteCodeSection
                        
                        // Action Buttons
                        actionButtons
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingScanner) {
            QRCodeScannerView { code in
                inviteCode = code
                showingScanner = false
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Join Group")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.top, 10)
    }
    
    private var illustrationView: some View {
        ZStack {
            // Background Circle
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 140, height: 140)
            
            // Overlapping Circles Animation
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(accentColor.opacity(0.3 - Double(index) * 0.1))
                    .frame(width: 60 - CGFloat(index * 10), height: 60 - CGFloat(index * 10))
                    .offset(x: CGFloat(index * 15 - 15), y: 0)
            }
            
            // Center Icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(accentColor)
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 12) {
            Text("Join a Group")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Enter an 8-character invite code\nto join an existing group")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }
    
    private var inviteCodeSection: some View {
        VStack(spacing: 16) {
            // Invite Code Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Invite Code")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack {
                    TextField("XXXXXXXX", text: $inviteCode)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(inviteCode.isEmpty ? Color.white.opacity(0.1) : accentColor, lineWidth: 2)
                        )
                        .onChange(of: inviteCode) { newValue in
                            // Limit to 8 characters and uppercase
                            let filtered = String(newValue.prefix(8).uppercased().filter { $0.isLetter || $0.isNumber })
                            if filtered != newValue {
                                inviteCode = filtered
                            }
                        }
                    
                    Button(action: { showingScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(accentColor.opacity(0.2))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(accentColor, lineWidth: 1)
                            )
                    }
                }
            }
            
            // Helper Text
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Text("Ask a group member for the invite code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            // Join Button
            Button(action: joinGroup) {
                HStack(spacing: 8) {
                    if dataManager.isJoiningGroup {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Text(dataManager.isJoiningGroup ? "Joining..." : "Join Group")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: isFormValid ? [accentColor, accentColor.opacity(0.8)] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: isFormValid ? accentColor.opacity(0.3) : Color.clear, radius: 12, x: 0, y: 6)
            }
            .disabled(!isFormValid || dataManager.isJoiningGroup)
            .scaleEffect(dataManager.isJoiningGroup ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: dataManager.isJoiningGroup)
            
            // Alternative Actions
            VStack(spacing: 12) {
                Text("or")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Button(action: { showingScanner = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Scan QR Code")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    private func joinGroup() {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        dataManager.joinGroup(inviteCode: trimmedCode)
        
        // Close the view when group is joined
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !dataManager.isJoiningGroup {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct QRCodeScannerView: View {
    let onCodeScanned: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Scan QR Code")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Point your camera at a group's QR code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    // QR Scanner Placeholder
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#7289da"), lineWidth: 3)
                        .frame(width: 250, height: 250)
                        .overlay(
                            VStack(spacing: 16) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 60))
                                    .foregroundColor(Color(hex: "#7289da"))
                                
                                Text("Camera access required")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        )
                    
                    // Manual Input Option
                    Button(action: {
                        // For demo purposes, simulate a scanned code
                        onCodeScanned("DEMO1234")
                    }) {
                        Text("Demo: Use Sample Code")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#7289da"))
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.white)
            )
        }
    }
} 