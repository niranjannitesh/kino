//
//  PlayerScreen.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//

import SwiftUI
import VLCKit

struct PlayerScreen: View {
    @Bindable var viewModel: KinoViewModel
    @State private var player: VLCMediaPlayer = VLCMediaPlayer()
    @State private var showPanel = true
    @State private var panelPosition = CGPoint(x: 0, y: 0)
    @State private var isDragging = false
    @State private var showChat = true
    @State private var isCollapsed = true
    
    @State private var lastActivityTime = Date()
    @State private var shouldHideControls = false
    @State private var isMouseInView = false
    @State private var isCursorHidden = false
    
    let inactivityTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    let inactivityThreshold: TimeInterval = 3.0
    
    @State private var lastSyncTime = Date()
    @State private var syncDebounceTimer: Timer?
    private let syncDebounceInterval: TimeInterval = 0.5
    
    @State private var lastSyncPosition: Float = 0
    @State private var syncThreshold: Float = 0.05 // 5% threshold
    
    
    @State private var isBuffering = false
    
    private func showCursor() {
        if isCursorHidden {
            DispatchQueue.main.async {
                NSCursor.unhide()
                isCursorHidden = false
            }
        }
    }
    
    private func hideCursor() {
        if !isCursorHidden && !isCollapsed && !isDragging {
            DispatchQueue.main.async {
                NSCursor.hide()
                isCursorHidden = true
            }
        }
    }
    
    private func handleActivity() {
        lastActivityTime = Date()
        shouldHideControls = false
        
        showCursor()
    }
    
    private func checkInactivity() {
        guard isMouseInView else { return }
        
        let timeSinceLastActivity = Date().timeIntervalSince(lastActivityTime)
        if timeSinceLastActivity >= inactivityThreshold {
            shouldHideControls = true
            hideCursor()
        }
    }
    
    private func getWindowSize() -> CGSize {
        guard let window = NSApp.windows.first else { return .zero }
        let frame = window.frame
        return CGSize(width: frame.width, height: frame.height)
    }
    
    private func calculatePanelPosition() -> CGPoint {
        let windowSize = getWindowSize()
        let width = isCollapsed ? 200.0 : 320.0
        let height = isCollapsed ? 120.0 : 430.0
        let paddingX: CGFloat = 20
        let paddingY: CGFloat = 80
        
        return CGPoint(
            x: windowSize.width - width - paddingX,
            y: windowSize.height - height - paddingY
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                KinoVideoPlayer(
                    player: player,
                    shouldHideControls: shouldHideControls,
                    viewModel: viewModel,
                    isBuffering: $isBuffering,
                    onStateChange: { isPlaying, position in
                        guard !isBuffering else { return }
                        
                        if !viewModel.roomViewModel.isInternalStateChange {
                            // Debounce sync updates
                            syncDebounceTimer?.invalidate()
                            syncDebounceTimer = Timer.scheduledTimer(withTimeInterval: syncDebounceInterval, repeats: false) { _ in
                                viewModel.roomViewModel.handlePlayerStateChange(
                                    state: PlayerState(
                                        isPlaying: isPlaying,
                                        position: position
                                    )
                                )
                            }
                        }
                    }
                )
                .ignoresSafeArea()
                .onDisappear {
                    player.stop()
                }.onContinuousHover(coordinateSpace: .local) { phase in
                    switch phase {
                    case .active:
                        handleActivity()
                    case .ended:
                        break
                    }
                }
                
                FloatingPanel(
                    position: $panelPosition,
                    isDragging: $isDragging,
                    isCollapsed: $isCollapsed
                ) {
                    ChatPanel(showChat: $showChat, isCollapsed: $isCollapsed)
                }.zIndex(1)
                    .onHover { hovering in
                        // Always show cursor when hovering over chat panel
                        if hovering && isCursorHidden {
                            NSCursor.unhide()
                            isCursorHidden = false
                        }
                    }
            }
            .background(Color.black)
            .onAppear {
                panelPosition = calculatePanelPosition()
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                panelPosition = calculatePanelPosition()
            }
            .onKeyPress(.space) {
                guard let window = NSApp.keyWindow,
                      !(window.firstResponder is NSTextView),
                      !isBuffering // Don't toggle if buffering
                else { return .ignored }
                
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
                
                return .handled
            }
            .onHover { isHovering in
                isMouseInView = isHovering
                if isHovering {
                    handleActivity()
                } else {
                    // Show cursor when mouse leaves the view
                    if isCursorHidden {
                        NSCursor.unhide()
                        isCursorHidden = false
                    }
                }
            }
            .onReceive(inactivityTimer) { _ in
                checkInactivity()
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        handleActivity()
                    }
            )
        }.onAppear {
            viewModel.roomViewModel.setPlayerDelegate(self)
        }
    }
}


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension PlayerScreen: WebRTCServiceDelegate {
    func webRTC(didReceivePlayerState state: PlayerState) {
        guard !viewModel.roomViewModel.isInternalStateChange else { return }

        DispatchQueue.main.async {
            viewModel.roomViewModel.isInternalStateChange = true
            
            if state.isSeekEvent {
                // For seek events, always sync position immediately
                player.position = state.position
                
                // Update play state after seek
                if state.isPlaying != player.isPlaying {
                    state.isPlaying ? player.play() : player.pause()
                }
            } else {
                // For regular playback, use existing sync logic
                let positionDiff = abs(state.position - player.position)
                if positionDiff > 0.05 { // 5% threshold
                    player.position = state.position
                }
                
                if state.isPlaying != player.isPlaying {
                    state.isPlaying ? player.play() : player.pause()
                }
            }
            
            viewModel.roomViewModel.isInternalStateChange = false
        }
    }
    
    func webRTC(didReceiveFileStream message: FileStreamMessage) {
        viewModel.roomViewModel.fileStreamManager.handleFileStream(message)
    }
    
    private func handleReceivedPlayerState(_ state: PlayerState) {
        // Don't sync while buffering to prevent jumping
        guard !isBuffering else { return }
        
        let positionDiff = abs(state.position - player.position)
        
        // Only sync position if difference is significant
        if positionDiff > syncThreshold {
            // Store last synced position
            lastSyncPosition = state.position
            player.position = state.position
        }
        
        // Always sync play/pause state
        if state.isPlaying != player.isPlaying {
            state.isPlaying ? player.play() : player.pause()
        }
    }
}
