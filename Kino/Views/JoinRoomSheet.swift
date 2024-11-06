//
//  JoinRoomSheet.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//
import SwiftUI

struct RoomPreview {
    let name: String
    let movie: String
    let participants: [Participant]
}


struct JoinRoomSheet: View {
    @Bindable var viewModel: KinoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = ""
    @State private var roomCode: String = ""
    
    // Mock data for room preview
    private let roomPreview = RoomPreview(
        name: "Movie Night",
        movie: "Blade Runner 2049",
        participants: [
            Participant(name: "Nitesh", status: "Host", avatar: "N"),
            Participant(name: "Kriti", status: "Watching", avatar: "K"),
        ]
    )
    
    private func handleJoinRoom() {
            // Save the display name
        viewModel.displayName = displayName
        
        // Join the room
        Task {
            await viewModel.roomViewModel.joinRoom(code: roomCode)
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
                    RoomPreviewCard(preview: roomPreview)
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

private struct RoomPreviewCard: View {
    let preview: RoomPreview
    
    var body: some View {
        VStack(spacing: 16) {
            RoomInfo(preview: preview)
            ParticipantsList(participants: preview.participants)
        }
        .padding(16)
        .background(KinoTheme.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct RoomInfo: View {
    let preview: RoomPreview
    
    var body: some View {
        HStack(spacing: 12) {
            Text("🎬")
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(KinoTheme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.name)
                    .font(.custom("OpenSauceTwo-Bold", size: 14))
                    .foregroundStyle(KinoTheme.textPrimary)
                
                Text("\(preview.movie) • \(preview.participants.count) watching")
                    .font(.custom("OpenSauceTwo-Regular", size: 12))
                    .foregroundStyle(KinoTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KinoTheme.surfaceBorder)
                .frame(height: 1)
        }
    }
}

private struct ParticipantsList: View {
    let participants: [Participant]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(participants) { participant in
                Text(participant.avatar)
                    .font(.custom("OpenSauceTwo-Medium", size: 12))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(KinoTheme.accentGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
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
