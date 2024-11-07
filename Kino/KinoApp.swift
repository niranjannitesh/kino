//
//  KinoApp.swift
//  Kino
//
//  Created by Nitesh on 05/11/24.
//

import SwiftUI
import VLCKit
import WebRTC


struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let sender: String
    let time: String
    let isSent: Bool
}

struct Participant: Identifiable {
    let id: UUID
    var name: String
    var status: String
    let avatar: String
    var isAudioEnabled: Bool
    var videoTrack: RTCVideoTrack?
    var isLocal: Bool
}


struct PlayerState: Codable {
    let isPlaying: Bool
    let position: Float
    let isSeekEvent: Bool
    
    init(isPlaying: Bool, position: Float, isSeekEvent: Bool = false) {
        self.isPlaying = isPlaying
        self.position = position
        self.isSeekEvent = isSeekEvent
    }
}

enum KinoScreen {
    case home
    case player
}

@Observable
class ChatViewModel {
    var participants: [Participant] = []
    
    let messages = [
        ChatMessage(text: "This scene is amazing!", sender: "Sarah", time: "2m ago", isSent: false),
        ChatMessage(
            text: "Yeah, the cinematography is incredible", sender: "You", time: "1m ago", isSent: true),
        ChatMessage(
            text: "The score really adds to the tension", sender: "Alex", time: "Just now", isSent: false),
        ChatMessage(
            text: "Definitely! This is my favorite part coming up", sender: "You", time: "Just now",
            isSent: true),
    ]
    
    func updateParticipantVideo(id: UUID, track: RTCVideoTrack?) {
            DispatchQueue.main.async {
                RTCLogger.shared.log("Participants", "Updating video track for participant: \(id)")
                
                if let index = self.participants.firstIndex(where: { $0.id == id }) {
                    var participant = self.participants[index]
                    participant.videoTrack = track
                    self.participants[index] = participant
                    RTCLogger.shared.log("Participants", "Video track updated successfully")
                } else {
                    RTCLogger.shared.log("Participants", "Warning: No participant found for video track update")
                }
            }
        }
    
    func updateOrAddParticipant(_ participant: Participant) {
        DispatchQueue.main.async {
            RTCLogger.shared.log("Participants", "Updating/adding participant: \(participant.id)")
            
            if let index = self.participants.firstIndex(where: { $0.id == participant.id }) {
                // Update existing participant
                var updatedParticipant = self.participants[index]
                
                // Preserve video track if new one is nil
                if participant.videoTrack != nil {
                    updatedParticipant.videoTrack = participant.videoTrack
                }
                
                updatedParticipant.name = participant.name
                updatedParticipant.status = participant.status
                updatedParticipant.isAudioEnabled = participant.isAudioEnabled
                
                RTCLogger.shared.log("Participants", "Updated existing participant: \(updatedParticipant.id)")
                self.participants[index] = updatedParticipant
            } else {
                // Add new participant
                RTCLogger.shared.log("Participants", "Adding new participant: \(participant.id)")
                self.participants.append(participant)
            }
        }
    }
}

@Observable
class RoomViewModel {
    private let webRTCService: WebRTCService
    private var lastSyncTime: TimeInterval = 0
    let fileStreamManager: FileStreamManager
    var isInternalStateChange = false
    
    var roomCode: String = ""
    var isHost: Bool = false
    var isConnected: Bool = false
    var error: String?
    
    init() {
        webRTCService = WebRTCService()
        fileStreamManager = FileStreamManager(webRTCService: webRTCService)
    }
    
    func createRoom(displayName: String) async {
        do {
            isHost = true
            roomCode = try await webRTCService.createRoom(displayName: displayName)
        } catch {
            self.error = "Failed to create room: \(error.localizedDescription)"
        }
    }
    
    func joinRoom(code: String, displayName: String) async {
        do {
            isHost = false
            roomCode = code
            try await webRTCService.joinRoom(code: code, displayName: displayName)
        } catch {
            self.error = "Failed to join room: \(error.localizedDescription)"
        }
    }
    
    
    func handlePlayerStateChange(state: PlayerState) {
        guard !isInternalStateChange else { return }
        let currentTime = Date().timeIntervalSince1970
        
        // Only send updates if:
        // 1. It's a seek event (immediate sync needed)
        // 2. Or enough time has passed since last sync
        if state.isSeekEvent || (currentTime - lastSyncTime) >= 0.5 {
            webRTCService.sendPlayerState(state)
            lastSyncTime = currentTime
        }
    }
    
    func setPlayerDelegate(_ delegate: WebRTCServiceDelegate) {
        webRTCService.delegate = delegate
    }
}

@Observable
class KinoViewModel {
    var roomViewModel = RoomViewModel()
    var chatViewModel = ChatViewModel()
    
    var currentScreen: KinoScreen = .home
    var showNewRoomSheet = false
    var showJoinSheet = false
    
    var isInRoom: Bool {
        !roomViewModel.roomCode.isEmpty
    }
    
    // Leave room function
    func leaveRoom() {
        roomViewModel.roomCode = ""
        roomViewModel.isHost = false
        roomViewModel.isConnected = false
        currentScreen = .home
    }
}

@main
struct KinoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().preferredColorScheme(.dark)
        }
#if os(macOS)
        .windowStyle(.hiddenTitleBar)
#endif
    }
}
