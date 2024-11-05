//
//  PlayerScreen.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//

import AVKit
import SwiftUI

struct PlayerScreen: View {
    @Bindable var viewModel: KinoViewModel
    @State private var player = AVPlayer(
        url: Bundle.main.url(forResource: "sample", withExtension: "mp4") ??
                    URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!
    )
    @State private var showPanel = true
    @State private var panelPosition = CGPoint(x: 0, y: 0)
    @State private var isDragging = false
    @State private var showChat = true
    @State private var isCollapsed = false


    var body: some View {
        GeometryReader { geometry in
            ZStack (alignment: .topLeading) {
                VideoPlayer(player: player)
                    .ignoresSafeArea()

                FloatingPanel(
                    position: $panelPosition,
                    isDragging: $isDragging,
                    isCollapsed: $isCollapsed
                ) {
                    ChatPanel(showChat: $showChat, isCollapsed: $isCollapsed)
                }.zIndex(1)
            }
            .background(Color.black)
            .onAppear {
                panelPosition = CGPoint(
                    x: geometry.size.width - 160, // Center horizontally
                    y: geometry.size.height - 240  // Center vertically
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
                        let paddingY: CGFloat = isCollapsed ? 60 : 80
                        let paddingX: CGFloat = isCollapsed ? 10 : 20
                        let panelWidth = isCollapsed ? 200.0 : 320.0

                        // Constrain x position to screen bounds
                        let minX = paddingX
                        let maxX = frame.width - panelWidth - paddingX
                        position.x = max(minX, min(maxX, position.x))

                        // Constrain y position to screen bounds
                        let minY = 0.0
                        let maxY = frame.height - (isCollapsed ? 120 : 480) - paddingY
                        position.y = max(minY, min(maxY, position.y))

                        // Dock to right edge if near
                        if position.x > frame.width - 100 {
                            withAnimation(.spring(response: 0.3)) {
                                position.x = maxX
                            }
                        }
                        // Dock to left edge if near
                        else if position.x < paddingY + 100 {
                            withAnimation(.spring(response: 0.3)) {
                                position.x = minX
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
        Participant(name: "Nitesh", status: "Host", avatar: "N"),
        Participant(name: "Kriti", status: "Watching", avatar: "K"),
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
