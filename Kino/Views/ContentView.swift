//
//  ContentView.swift
//  Kino
//
//  Created by Nitesh on 05/11/24.
//

import SwiftUI
import AVKit

enum KinoScreen {
    case home
    case player
}

@Observable
class KinoViewModel {
    var currentScreen: KinoScreen = .player
    var showNewRoomSheet = false
    var showJoinSheet = false
}

// MARK: - Theme
struct KinoTheme {
    static let bgPrimary = Color(hex: "0D0D0F")
    static let bgSecondary = Color(hex: "1C1C1E").opacity(0.95) // Adjusted to match
    static let bgTertiary = Color(hex: "28282A").opacity(0.8)
    static let accent = Color(hex: "6C5DD3")
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "6C5DD3"), Color(hex: "8A7AFF")],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let messageBg = Color(hex: "1C1C20").opacity(0.8)
    static let surfaceBorder = Color.white.opacity(0.08)
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.6)
}

struct ContentView: View {
    @State private var viewModel = KinoViewModel()
    
    var body: some View {
        Group {
            switch viewModel.currentScreen {
            case .home:
                HomeScreen(viewModel: viewModel)
            case .player:
                PlayerScreen(viewModel: viewModel)
            }
        }
#if os(macOS)
        .frame(minWidth: 800, minHeight: 600)
#endif
    }
}

#if os(macOS)
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        return effectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    }
}
#endif

// MARK: Home Screen
struct HomeScreen: View {
    @Bindable var viewModel: KinoViewModel
    
    var body: some View {
        ZStack {
#if os(macOS)
            // Base background color with material
            Rectangle()
                .fill(.background.opacity(0.5))
                .background(VisualEffectView())
                .ignoresSafeArea()
#endif
            ZStack {
                // Background gradient blurs
                Circle()
                    .fill(KinoTheme.accent)
                    .frame(width: 300, height: 300)
                    .blur(radius: 160)
                    .opacity(0.1)
                    .offset(x: 150, y: -150)
                
                Circle()
                    .fill(Color(hex: "8A7AFF"))
                    .frame(width: 300, height: 300)
                    .blur(radius: 160)
                    .opacity(0.1)
                    .offset(x: -150, y: 150)
                
                // Content
                VStack(spacing: 48) {
                    // Logo
                    //                    VStack(spacing: 16) {
                    //                        ZStack {
                    //                            RoundedRectangle(cornerRadius: 16)
                    //                                .fill(KinoTheme.accentGradient)
                    //                                .frame(width: 64, height: 64)
                    //                                .overlay {
                    //                                    Text("K")
                    //                                        .font(.system(size: 32, weight: .bold))
                    //                                        .foregroundColor(.white)
                    //                                }
                    //                                .shadow(color: KinoTheme.accent.opacity(0.3), radius: 20)
                    //                        }
                    //                    }
                    
                    // Action Cards
                    HStack(spacing: 20) {
                        ActionCard(
                            emoji: "📽️",
                            title: "Host Watch Party",
                            badge: "New Room",
                            action: { viewModel.showNewRoomSheet = true }
                        )
                        
                        ActionCard(
                            emoji: "🎟️",
                            title: "Join Party",
                            badge: "Join",
                            action: { viewModel.showJoinSheet = true }
                        )
                    }
                    .frame(maxWidth: 640)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
#if os(macOS)
        //        .sheet(isPresented: $viewModel.showNewRoomSheet) {
        //            NewRoomSheet(viewModel: viewModel)
        //                .frame(width: 560, height: 620)
        //        }
        //        .sheet(isPresented: $viewModel.showJoinSheet) {
        //            JoinRoomSheet(viewModel: viewModel)
        //                .frame(width: 420, height: 480)
        //        }
#else
        //        .sheet(isPresented: $viewModel.showNewRoomSheet) {
        //            NewRoomSheet(viewModel: viewModel)
        //        }
        //        .sheet(isPresented: $viewModel.showJoinSheet) {
        //            JoinRoomSheet(viewModel: viewModel)
        //        }
#endif
    }
}

struct ActionCard: View {
    let emoji: String
    let title: String
    let badge: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack (alignment: .top) {
                    // Icon
                    Text(emoji)
                        .font(.custom("OpenSauceTwo-Black", size: 32))
                        .frame(width: 48, height: 48)
                        .background(KinoTheme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                    
                    // Badge
                    Text(badge)
                    //                        .font(.system(size: 12, weight: .medium))
                        .font(.custom("OpenSauceTwo-Medium", size: 12))
                        .foregroundColor(KinoTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(KinoTheme.accent.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(KinoTheme.accent.opacity(0.2))
                        )
                }
                
                Text(title)
                //                    .font(.system(size: 15, weight: .semibold))
                    .font(.custom("OpenSauceTwo-Bold", size: 15))
                    .foregroundStyle(KinoTheme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(KinoTheme.bgSecondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isHovering ? KinoTheme.accent : KinoTheme.surfaceBorder)
                            .animation(.smooth(duration: 0.2), value: isHovering)
                        
                    }
            }
            .shadow(color: KinoTheme.accent.opacity(isHovering ? 0.1 : 0), radius: 20)
            //            .scaleEffect(isHovering ? 1.02 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
#if os(macOS)
        .focusEffectDisabled()
#endif
    }
}

// MARK: Player Screen
struct PlayerScreen: View {
    @Bindable var viewModel: KinoViewModel
    @State private var player = AVPlayer()
    @State private var showPanel = true
    @State private var panelPosition = CGPoint(x: 0, y: 0)
    @State private var isDragging = false
    @State private var showChat = true
    @State private var isCollapsed = false
    
    init(viewModel: KinoViewModel) {
        self.viewModel = viewModel
        
        // Initialize player with the video URL
        let videoURL = URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
        let playerItem = AVPlayerItem(url: videoURL)
        
        // Initialize state
        _player = State(initialValue: AVPlayer(playerItem: playerItem))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                
                FloatingPanel(
                    position: $panelPosition,
                    isDragging: $isDragging,
                    isCollapsed: $isCollapsed
                ) {
                    ChatPanel(showChat: $showChat, isCollapsed: $isCollapsed)
                }
            }
            .background(Color.black)
            .onAppear {
                panelPosition = CGPoint(
                    x: geometry.size.width - 340,
                    y: 20
                )
            }
        }
    }
}

struct FloatingPanel<Content: View>: View {
    @Binding var position: CGPoint
    @Binding var isDragging: Bool
    @Binding var isCollapsed: Bool
    let content: Content
    
    @State private var dragOffset = CGSize.zero
    @State private var opacity: Double = 1.0
    
    init(position: Binding<CGPoint>, isDragging: Binding<Bool>, isCollapsed: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._position = position
        self._isDragging = isDragging
        self._isCollapsed = isCollapsed
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: isCollapsed ? 8 : 16))
        .background {
            RoundedRectangle(cornerRadius: isCollapsed ? 8 : 16)
                .fill(isCollapsed ?
                      KinoTheme.bgSecondary.opacity(0.6) :
                        KinoTheme.bgSecondary)
                .overlay {
                    RoundedRectangle(cornerRadius: isCollapsed ? 8 : 16)
                        .strokeBorder(KinoTheme.surfaceBorder.opacity(isCollapsed ? 0.3 : 1))
                }
        }
        .shadow(color: Color.black.opacity(isDragging ? 0.3 : 0.15), radius: isDragging ? 30 : 20)
        .frame(width: isCollapsed ? 200 : 320, height: isCollapsed ? 120 : 480)
        .offset(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    position.x += value.translation.width
                    position.y += value.translation.height
                    dragOffset = .zero
                    
                    // Auto-dock to edges if near
                    if let window = NSApp.windows.first {
                        let screen = window.screen ?? NSScreen.main
                        let frame = screen?.frame ?? .zero
                        let padding: CGFloat = 20
                        
                        // Dock to right edge
                        if position.x > frame.width - 200 {
                            withAnimation(.spring(response: 0.3)) {
                                position.x = frame.width - (isCollapsed ? 180 : 340)
                            }
                        }
                        // Dock to left edge
                        else if position.x < 20 {
                            withAnimation(.spring(response: 0.3)) {
                                position.x = padding
                            }
                        }
                    }
                }
        )
        .gesture(
            // Double tap to collapse/expand
            TapGesture(count: 2).onEnded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isCollapsed.toggle()
                }
            }
        )
        .onChange(of: isCollapsed) { _, collapsed in
            // Adjust position when collapsing to keep panel visible
            if collapsed {
                if position.x + 160 > NSScreen.main?.frame.width ?? 0 {
                    position.x = (NSScreen.main?.frame.width ?? 0) - 180
                }
            }
        }
    }
}

struct PanelTab: View {
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        Text(icon)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? KinoTheme.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// Mock data structure
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let sender: String
    let time: String
    let isSent: Bool
}

struct Participant: Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let avatar: String
}

class ChatViewModel: ObservableObject {
    let messages = [
        ChatMessage(text: "This scene is amazing!", sender: "Sarah", time: "2m ago", isSent: false),
        ChatMessage(text: "Yeah, the cinematography is incredible", sender: "You", time: "1m ago", isSent: true),
        ChatMessage(text: "The score really adds to the tension", sender: "Alex", time: "Just now", isSent: false),
        ChatMessage(text: "Definitely! This is my favorite part coming up", sender: "You", time: "Just now", isSent: true)
    ]
    
    let participants = [
        Participant(name: "Nitesh", status: "Host", avatar: "A"),
        Participant(name: "Kriti", status: "Watching", avatar: "S"),
    ]
}

struct ChatPanel: View {
    @Binding var showChat: Bool
    @Binding var isCollapsed: Bool
    @StateObject private var viewModel = ChatViewModel()
    @State private var message = ""
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                
                if !isCollapsed {
                    Text("Room: Movie Night")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KinoTheme.textPrimary)
                }
                
                
                Spacer()
                
                HStack(spacing: 8) {
                    if !isCollapsed {
                        // Chat/Participants toggle
                        HStack(spacing: 2) {
                            PanelTab(icon: "👀", isSelected: !showChat)
                                .onTapGesture { withAnimation { showChat = false } }
                            
                            PanelTab(icon: "💬", isSelected: showChat)
                                .onTapGesture { withAnimation { showChat = true } }
                        }
                        .padding(4)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // Collapse button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .foregroundColor(KinoTheme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(Color.black.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, isCollapsed ? 4 : 12)
            .padding(.vertical, isCollapsed ? 4 : 12)
            .background(KinoTheme.bgTertiary)
            
            if isCollapsed {
                // Compact grid of participant videos
                CompactParticipantGrid(participants: viewModel.participants)
            } else {
                if showChat {
                    ChatView(messages: viewModel.messages)
                } else {
                    ParticipantsView(participants: viewModel.participants, isCollapsed: isCollapsed)
                }
            }
        }
    }
}



//struct ChatPanel: View {
//    @Binding var showChat: Bool
//    @Binding var isCollapsed: Bool
//    @StateObject private var viewModel = ChatViewModel()
//    @State private var message = ""
//    @State private var isHovering = false
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // Collapsed Header
//            if isCollapsed {
//                HStack(spacing: 8) {
//                    Circle()
//                        .fill(KinoTheme.accent)
//                        .frame(width: 8, height: 8)
//
//                    Text(showChat ? "Chat" : "Participants")
//                        .font(.system(size: 12, weight: .medium))
//                        .foregroundStyle(KinoTheme.textPrimary)
//
//                    Spacer()
//
//                    Text("\(viewModel.participants.count)")
//                        .font(.system(size: 12, weight: .medium))
//                        .foregroundStyle(KinoTheme.textSecondary)
//                }
//                .padding(.horizontal, 12)
//                .padding(.vertical, 8)
//                .background(isHovering ? KinoTheme.bgTertiary : Color.clear)
//                .onHover { hovering in
//                    withAnimation(.easeInOut(duration: 0.2)) {
//                        isHovering = hovering
//                    }
//                }
//
//            } else {
//                // Expanded Header
//                HStack {
//                    Text("Room: Movie Night")
//                        .font(.system(size: 13, weight: .semibold))
//                        .foregroundStyle(KinoTheme.textPrimary)
//
//                    Spacer()
//
//                    HStack(spacing: 8) {
//                        // Chat/Participants toggle
//                        HStack(spacing: 2) {
//                            PanelTab(icon: "👀", isSelected: !showChat)
//                                .onTapGesture { withAnimation { showChat = false } }
//
//                            PanelTab(icon: "💬", isSelected: showChat)
//                                .onTapGesture { withAnimation { showChat = true } }
//                        }
//                        .padding(4)
//                        .background(Color.black.opacity(0.2))
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//
//                        // Collapse button
//                        Button(action: {
//                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
//                                isCollapsed.toggle()
//                            }
//                        }) {
//                            Image(systemName: "chevron.up")
//                                .foregroundColor(KinoTheme.textSecondary)
//                                .frame(width: 24, height: 24)
//                                .background(Color.black.opacity(0.2))
//                                .clipShape(RoundedRectangle(cornerRadius: 6))
//                        }
//                        .buttonStyle(.plain)
//                    }
//                }
//                .padding(12)
//                .background(KinoTheme.bgTertiary)
//
//                if showChat {
//                    ChatView(messages: viewModel.messages)
//                } else {
//                    ParticipantsView(participants: viewModel.participants, isCollapsed: isCollapsed)
//                }
//            }
//        }
//    }
//}

struct ChatView: View {
    let messages: [ChatMessage]
    @State private var message = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(16)
            }
            
            // Input
            HStack(spacing: 8) {
                TextField("Type a message...", text: $message)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(KinoTheme.messageBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button(action: {}) {
                    Text("↑")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 28, height: 28)
                        .background(KinoTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(KinoTheme.bgTertiary)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: message.isSent ? .trailing : .leading) {
            HStack {
                if message.isSent { Spacer() }
                
                VStack(alignment: message.isSent ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 13))
                        .foregroundColor(message.isSent ? .white : KinoTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(message.isSent ? KinoTheme.accent : KinoTheme.messageBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .clipShape(
                            .rect(
                                topLeadingRadius: message.isSent ? 12 : 4,
                                bottomLeadingRadius: message.isSent ? 12 : 12,
                                bottomTrailingRadius: message.isSent ? 4 : 12,
                                topTrailingRadius: message.isSent ? 12 : 12
                            )
                        )
                    
                    HStack(spacing: 4) {
                        Text(message.sender)
                            .fontWeight(.medium)
                        Text("•")
                        Text(message.time)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(KinoTheme.textSecondary)
                }
                
                if !message.isSent { Spacer() }
            }
        }
    }
}

struct CompactParticipantGrid: View {
    let participants: [Participant]
    
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ],
            spacing: 4
        ) {
            ForEach(participants) { participant in
                CompactParticipantCell(participant: participant)
            }
        }
        .padding(4)
    }
}

struct CompactParticipantCell: View {
    let participant: Participant
    @State private var isHovering = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Video placeholder
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay {
                    Text(participant.avatar)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KinoTheme.textPrimary)
                }
            
            // Name badge that shows on hover
            if isHovering {
                Text(participant.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(KinoTheme.textPrimary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
                    .transition(.opacity)
            }
            
            // Status indicator
            Circle()
                .fill(participant.status == "Host" ? KinoTheme.accent : Color.green)
                .frame(width: 6, height: 6)
                .padding(4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct ParticipantsView: View {
    let participants: [Participant]
    let isCollapsed: Bool
    
    var body: some View {
        if isCollapsed {
            // Horizontal layout when collapsed
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(participants) { participant in
                        ParticipantCell(participant: participant, isCollapsed: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        } else {
            // Vertical layout when expanded
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(participants) { participant in
                        ParticipantCell(participant: participant, isCollapsed: false)
                    }
                }
                .padding(12)
            }
        }
    }
}


struct ParticipantCell: View {
    let participant: Participant
    let isCollapsed: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Video area - maintain 16:9 ratio even when collapsed
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit) // Always keep 16:9
                    .frame(width: isCollapsed ? 200 : nil) // Width for collapsed state
                
                Text(participant.avatar)
                    .font(.system(size: isCollapsed ? 14 : 18, weight: .semibold))
                    .foregroundStyle(KinoTheme.textPrimary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                Text(participant.name)
                    .font(.system(size: isCollapsed ? 10 : 12, weight: .medium))
                    .foregroundStyle(KinoTheme.textPrimary)
                    .padding(.horizontal, isCollapsed ? 4 : 8)
                    .padding(.vertical, isCollapsed ? 2 : 4)
                    .background(.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(isCollapsed ? 4 : 8)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
