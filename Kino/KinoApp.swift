//
//  KinoApp.swift
//  Kino
//
//  Created by Nitesh on 05/11/24.
//

import SwiftUI
import VLCKit

enum KinoScreen {
    case home
    case player
}

@Observable
class RoomViewModel {
    private let webRTCService: WebRTCService
    private var lastSyncTime: TimeInterval = 0
    var isInternalStateChange = false

    var roomCode: String = ""
    var isHost: Bool = false
    var isConnected: Bool = false
    var error: String?

    init() {
        webRTCService = WebRTCService()
    }

    // Create a new room
    func createRoom() async {
        do {
            isHost = true
            roomCode = try await webRTCService.createRoom()
        } catch {
            self.error = "Failed to create room: \(error.localizedDescription)"
        }
    }

    // Join existing room
    func joinRoom(code: String) async {
        do {
            isHost = false
            roomCode = code
            try await webRTCService.joinRoom(code: code)
        } catch {
            self.error = "Failed to join room: \(error.localizedDescription)"
        }
    }


    // Handle player state changes
    func handlePlayerStateChange(state: PlayerState) {
        guard !isInternalStateChange else { return }
        let currentTime = Date().timeIntervalSince1970
        webRTCService.sendPlayerState(state)
        lastSyncTime = currentTime
    }

    func setPlayerDelegate(_ delegate: WebRTCServiceDelegate) {
        webRTCService.delegate = delegate
    }
}

@Observable
class KinoViewModel {
    var roomViewModel = RoomViewModel()

    var currentScreen: KinoScreen = .home
    var showNewRoomSheet = false
    var showJoinSheet = false
    var roomName = ""
    var displayName = ""

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
