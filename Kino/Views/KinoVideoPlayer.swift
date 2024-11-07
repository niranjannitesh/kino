//
//  VideoPlayer.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//

import SwiftUI
import VLCKit
import UniformTypeIdentifiers


class VLCPlayerStateManager: NSObject, VLCMediaPlayerDelegate {
    let onStateChange: (Bool, Float) -> Void
    let onBufferingChange: (Bool) -> Void
    
    init(onStateChange: @escaping (Bool, Float) -> Void,
         onBufferingChange: @escaping (Bool) -> Void) {
        self.onStateChange = onStateChange
        self.onBufferingChange = onBufferingChange
        super.init()
    }
    
    
    func mediaPlayerStateChanged(_ notification: Notification) {
        guard let player = notification.object as? VLCMediaPlayer else { return }
        
        // More precise buffering state detection
        let isBuffering = player.state == .buffering || player.state == .opening
        onBufferingChange(isBuffering)
        
        // Only send state updates when in a stable state
        if player.state != .buffering && player.state != .opening {
            onStateChange(player.isPlaying, player.position)
        }
    }
    
    //    func mediaPlayerStateChanged(_ notification: Notification) {
    //        guard let player = notification.object as? VLCMediaPlayer else { return }
    //        if player.state != .buffering {
    //            onStateChange(player.isPlaying, player.position)
    //        }
    //
    //        if (player.state == .buffering || player.state == .opening) {
    //            onBufferingChange(true)
    //        } else if player.state == .playing || player.state == .paused {
    //            onBufferingChange(false)
    //        }
    //    }
    //
    //    // This captures position changes during seeking
    //    func mediaPlayerPositionChanged(_ notification: Notification) {
    //        guard let player = notification.object as? VLCMediaPlayer else { return }
    //        onStateChange(player.isPlaying, player.position)
    //    }
    //
    //    // This captures time changes during playback
    //    func mediaPlayerTimeChanged(_ notification: Notification) {
    //        guard let player = notification.object as? VLCMediaPlayer else { return }
    //        onStateChange(player.isPlaying, player.position)
    //    }
}

struct KinoVideoPlayer: View {
    let player: VLCMediaPlayer
    let shouldHideControls: Bool
    @Bindable var viewModel: KinoViewModel
    @Binding var isBuffering: Bool
    let onStateChange: (Bool, Float) -> Void
    
    @State private var stateManager: VLCPlayerStateManager?
    
    private let bufferingDebounceInterval: TimeInterval = 0.5
    @State private var bufferingDebounceTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video Content
                VLCPlayerView(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        let manager = VLCPlayerStateManager(
                            onStateChange: { isPlaying, position in
                                onStateChange(isPlaying, position)
                            },
                            onBufferingChange: { buffering in
                                isBuffering = buffering
                            }
                        )
                        player.delegate = manager
                        stateManager = manager
                    }
                
                if isBuffering && player.isPlaying {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                VideoControls(
                    player: player, viewModel: viewModel
                )
                .opacity(shouldHideControls ? 0 : 1)
                .offset(y: shouldHideControls ? 20 : 0)
                .animation(.easeInOut(duration: 0.2), value: shouldHideControls)
                
            }
            .background(Color.black)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldHideControls)
        }
    }
    
    
    
}

struct VideoControls: View {
    let player: VLCMediaPlayer
    @State private var isPlaying = false
    @State private var progress: Float = 0
    @State private var volume: Int = 100
    @State private var timeString = "00:00 / 00:00"
    @Bindable var viewModel: KinoViewModel
    
    
    @State private var showingFilePicker = false
    @State private var isStreaming = false
    
    
    
    // Timer just for UI updates, not for sync
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    private func formatTime(_ time: Int) -> String {
        let hours = time / 3600
        let minutes = (time % 3600) / 60
        let seconds = time % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func updateTimeString() {
        let current = formatTime(Int(player.time.intValue / 1000))
        let total = formatTime(Int(player.media?.length.intValue ?? 0) / 1000)
        timeString = "\(current) / \(total)"
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            // Controls background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    .black.opacity(0),
                    .black.opacity(0.5),
                    .black.opacity(0.8),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .overlay {
                VStack(spacing: 12) {
                    // Progress bar
                    Slider(
                        value: Binding(
                            get: { progress },
                            set: { newValue in
                                progress = newValue
                                player.position = newValue
                                
                                viewModel.roomViewModel.handlePlayerStateChange(
                                    state: PlayerState(
                                        isPlaying: player.isPlaying,
                                        position: newValue,
                                        isSeekEvent: true
                                    )
                                )
                            }
                        ), in: 0...1
                    )
                    .tint(KinoTheme.accent)
                    
                    HStack(spacing: 20) {
                        // Play/Pause button
                        Button(action: {
                            if player.isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .frame(width: 36, height: 36)
                                .background(KinoTheme.accent)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            showingFilePicker = true
                        }) {
                            Image(systemName: isStreaming ? "rays" : "doc.badge.plus")
                                .font(.system(size: 20))
                                .frame(width: 36, height: 36)
                                .background(KinoTheme.accent)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .fileImporter(
                            isPresented: $showingFilePicker,
                            allowedContentTypes: UTType.videoTypes
                        ) { result in
                            switch result {
                            case .success(let url):
                                let media = VLCMedia(url: url)
                                media.addOptions([
                                    "network-caching": "1500",
                                    "live-caching": "1500",
                                    "file-caching": "1500"
                                ])
                                player.media = media
                                player.play()
                                
                                if url.startAccessingSecurityScopedResource() {
                                    isStreaming = true
                                    viewModel.roomViewModel.fileStreamManager.startStreaming(url: url)
                                    url.stopAccessingSecurityScopedResource()
                                }
                            case .failure:
                                break
                            }
                        }
                        
                        // Time
                        Text(timeString)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        // Volume control
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 12))
                            
                            Slider(
                                value: Binding(
                                    get: { Double(volume) },
                                    set: { newValue in
                                        volume = Int(newValue)
                                        player.audio?.volume = Int32(newValue)
                                    }
                                ), in: 0...100
                            )
                            .frame(width: 100)
                            .tint(KinoTheme.accent)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onReceive(timer) { _ in
            progress = player.position
            updateTimeString()
            isPlaying = player.isPlaying
        }.onReceive(NotificationCenter.default.publisher(for: .streamingStarted)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                let media = VLCMedia(url: url)
                media.addOptions([
                    "network-caching": "1500",
                    "live-caching": "1500",
                    "file-caching": "1500"
                ])
                player.media = media
                player.play()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .streamingEnded)) { _ in
            isStreaming = false
        }
    }
}

struct VLCPlayerView: NSViewRepresentable {
    let player: VLCMediaPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        player.drawable = view
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension UTType {
    static var matroska: UTType {
        UTType(importedAs: "org.matroska.mkv")
    }
    
    static var videoTypes: [UTType] {
        [
            .movie,            // .mov
            .video,            // General video
            .mpeg4Movie,       // .mp4
            .matroska,        // .mkv
            .avi,             // .avi
            UTType(filenameExtension: "mkv")!,  // Fallback for MKV
            UTType(mimeType: "video/x-matroska")!, // Alternative MKV definition
            UTType(mimeType: "video/webm")!,    // WebM (similar container)
        ]
    }
}

