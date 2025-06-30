//
//  CreateGroupView.swift
//  upwork-project
//
//  Created by Boris Milev on 30.06.25.
//

import SwiftUI

struct CreateGroupView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var groupName = ""
    @State private var description = ""
    // Fixed values - all groups are private with 4 members
    private let isPrivate = true
    private let memberLimit = 4
    @State private var selectedEmoji = "🏠"
    @State private var selectedColor = "#7289da"
    @State private var showingEmojiPicker = false
    @State private var showingColorPicker = false
    
    let accentColor = Color(hex: "#7289da")
    
    let emojis = ["🏠", "🌟", "🚀", "🎯", "🎮", "🎵", "🍕", "⚡", "🔥", "💎", "🌈", "🎨", "📱", "🎪", "🌸", "🦄", "🍀", "🌙", "☀️", "🎃"]
    let colors = ["#7289da", "#ff6b6b", "#4ecdc4", "#45b7d1", "#96ceb4", "#ffeaa7", "#dda0dd", "#98d8c8", "#f7dc6f", "#bb8fce"]
    
    var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        groupName.count <= 50 &&
        description.count <= 200
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Group Avatar Preview
                        groupAvatarPreview
                        
                        // Form Fields
                        formFields
                        
                        // Create Button
                        createButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(selectedEmoji: $selectedEmoji)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $selectedColor)
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
            
            VStack(spacing: 2) {
                Text("Create Group")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Private • 4 Members Max")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.top, 10)
    }
    
    private var groupAvatarPreview: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: selectedColor).opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Text(selectedEmoji)
                    .font(.system(size: 48))
            }
            .overlay(
                Circle()
                    .stroke(Color(hex: selectedColor), lineWidth: 3)
            )
            .shadow(color: Color(hex: selectedColor).opacity(0.3), radius: 20, x: 0, y: 10)
            
            // Customization Buttons
            HStack(spacing: 16) {
                Button(action: { showingEmojiPicker = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 18))
                        
                        Text("Emoji")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
                
                Button(action: { showingColorPicker = true }) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: selectedColor))
                            .frame(width: 18, height: 18)
                        
                        Text("Color")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
            }
        }
    }
    
    private var formFields: some View {
        VStack(spacing: 20) {
            // Group Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Group Name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("Enter group name...", text: $groupName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(groupName.isEmpty ? Color.white.opacity(0.1) : accentColor, lineWidth: 1)
                    )
                
                HStack {
                    Spacer()
                    Text("\(groupName.count)/50")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (Optional)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                TextField("What's this group about?", text: $description, axis: .vertical)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(16)
                    .frame(minHeight: 80, alignment: .topLeading)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                
                HStack {
                    Spacer()
                    Text("\(description.count)/200")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
    }
    

    
    private var createButton: some View {
        Button(action: createGroup) {
            HStack(spacing: 8) {
                if dataManager.isCreatingGroup {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text(dataManager.isCreatingGroup ? "Creating..." : "Create Group")
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
        .disabled(!isFormValid || dataManager.isCreatingGroup)
        .scaleEffect(dataManager.isCreatingGroup ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: dataManager.isCreatingGroup)
    }
    
    private func createGroup() {
        let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        
        dataManager.createGroup(
            name: trimmedName,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            isPrivate: isPrivate,
            memberLimit: memberLimit,
            avatarColor: selectedColor,
            emoji: selectedEmoji
        )
        
        // Close the view when group is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !dataManager.isCreatingGroup {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @Environment(\.presentationMode) var presentationMode
    
    let emojis = ["🏠", "🌟", "🚀", "🎯", "🎮", "🎵", "🍕", "⚡", "🔥", "💎", "🌈", "🎨", "📱", "🎪", "🌸", "🦄", "🍀", "🌙", "☀️", "🎃", "🎄", "🎁", "🎂", "🎊", "🎉", "🎋", "🎌", "🏆", "🏅", "🥇", "⭐", "✨", "💫", "🌠"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text(emoji)
                                    .font(.system(size: 32))
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(selectedEmoji == emoji ? Color(hex: "#7289da").opacity(0.2) : Color.white.opacity(0.05))
                                    )
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Color(hex: "#7289da"))
            )
        }
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: String
    @Environment(\.presentationMode) var presentationMode
    
    let colors = ["#7289da", "#ff6b6b", "#4ecdc4", "#45b7d1", "#96ceb4", "#ffeaa7", "#dda0dd", "#98d8c8", "#f7dc6f", "#bb8fce", "#fd79a8", "#6c5ce7", "#a29bfe", "#fd79a8", "#fdcb6e", "#e17055", "#00b894", "#00cec9", "#0984e3", "#74b9ff"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                    )
                                    .shadow(color: Color(hex: color).opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(Color(hex: "#7289da"))
            )
        }
    }
} 