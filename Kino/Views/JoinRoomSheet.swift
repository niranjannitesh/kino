//
//  JoinRoomSheet.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//
import SwiftUI

struct JoinRoomSheet: View {
    @Bindable var viewModel: KinoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var roomCode: String = ""
    
    private func handleJoinRoom() {
        guard !displayName.isEmpty else { return }
        Task {
            await viewModel.roomViewModel.joinRoom(code: roomCode, displayName: displayName)
            await MainActor.run {
                viewModel.currentScreen = .player
                dismiss()
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Join Watch Party")
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
                    InputFields(displayName: $displayName, roomCode: $roomCode)
                }
                .padding(24)
            }
            
            SheetFooter(
                onCancel: { dismiss() },
                onAction: {
                    handleJoinRoom()
                }
            )
        }
        .background(KinoTheme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}


private struct InputFields: View {
    @Binding var displayName: String
    @Binding var roomCode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            InputField(
                label: "Your Display Name",
                placeholder: "Enter your name",
                text: $displayName
            )
            
            InputField(
                label: "Room Code",
                placeholder: "KINO-XXXXX",
                text: $roomCode
            )
            .textCase(.uppercase)
            .font(.custom("SF Mono", size: 16))
            .kerning(1)
        }
    }
}

private struct SheetFooter: View {
    let onCancel: () -> Void
    let onAction: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .buttonStyle(SecondaryButtonStyle())
            
            Button("Join Room", action: onAction)
                .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(KinoTheme.bgTertiary)
    }
}
