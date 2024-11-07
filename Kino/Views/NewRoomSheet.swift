//
//  NewRoomSheet.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//

import SwiftUI

struct NewRoomSheet: View {
    @Bindable var viewModel: KinoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""

    @State private var isCreatingRoom = false
    @State private var showJoinButton = false
    
    private func handleCreateRoom() {
        guard !displayName.isEmpty else { return }
        
        isCreatingRoom = true
        showJoinButton = false

        Task {
            await viewModel.roomViewModel.createRoom(displayName: displayName)
            await MainActor.run {
                isCreatingRoom = false
            
                if !viewModel.roomViewModel.roomCode.isEmpty {
                    withAnimation(.spring(response: 0.3)) {
                        showJoinButton = true
                    }
                }
            }
        }
    }
    
    private func handleJoinCreatedRoom() {
        viewModel.currentScreen = .player
        dismiss()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Watch Party")
                    .font(.custom("OpenSauceTwo-Bold", size: 16))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .frame(width: 24, height: 24)
                        .background(KinoTheme.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(KinoTheme.bgTertiary)

            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 20) {
                        InputField(
                            label: "Your Display Name",
                            placeholder: "Enter your name",
                            text: $displayName
                        )
                    }
            
                    // Room Code
                    VStack(spacing: 8) {
                Text("Room Code")
                    .font(.custom("OpenSauceTwo-Regular", size: 13))
                    .foregroundStyle(KinoTheme.textSecondary)
                
                if isCreatingRoom {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 36)
                } else if !viewModel.roomViewModel.roomCode.isEmpty {
                    CopyableRoomCode(code: viewModel.roomViewModel.roomCode)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("▯▯▯▯-▯▯▯▯▯")
                        .font(.custom("SF Mono", size: 24))
                        .fontWeight(.semibold)
                        .foregroundStyle(KinoTheme.textSecondary)
                        .kerning(2)
                }
                
                Text("Share this code with friends to invite them")
                    .font(.custom("OpenSauceTwo-Regular", size: 12))
                    .foregroundStyle(KinoTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(KinoTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(24)
            }
        
            
            // Footer
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                if showJoinButton {
                    Button("Join Room") {
                        handleJoinCreatedRoom()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button("Create Room") {
                        handleCreateRoom()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isCreatingRoom)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(KinoTheme.bgTertiary)
        }
        .animation(.spring(response: 0.3), value: isCreatingRoom)
        .animation(.spring(response: 0.3), value: viewModel.roomViewModel.roomCode)
        .background(KinoTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CopyableRoomCode: View {
    let code: String
    @State private var isCopied = false
    
    var body: some View {
        HStack(spacing: 12) {
            Text(code)
                .font(.custom("SF Mono", size: 24))
                .fontWeight(.semibold)
                .foregroundStyle(KinoTheme.accent)
                .kerning(2)
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                
                withAnimation {
                    isCopied = true
                }
                
                // Reset copy state after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isCopied = false
                    }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(isCopied ? .green : KinoTheme.textSecondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
    }
}

// Supporting Views
struct InputField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("OpenSauceTwo-Medium", size: 13))
                .foregroundStyle(KinoTheme.textSecondary)
            
            TextField("", text: $text)
                .font(.custom("OpenSauceTwo-Regular", size: 14))
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(KinoTheme.bgTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            isFocused ? KinoTheme.accent :
                                KinoTheme.surfaceBorder)
                }
                .placeholder(when: text.isEmpty) {
                    Text(placeholder)
                        .font(.custom("OpenSauceTwo-Regular", size: 14))
                        .foregroundStyle(KinoTheme.textSecondary)
                        .padding(.leading, 12)
                }.focused($isFocused)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("OpenSauceTwo-Medium", size: 13))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(KinoTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("OpenSauceTwo-Medium", size: 13))
            .foregroundStyle(KinoTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(KinoTheme.bgTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

// Helper View Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
