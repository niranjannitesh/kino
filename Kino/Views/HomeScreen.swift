//
//  HomeScreen 2.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//


import SwiftUI
import AVKit

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
        .sheet(isPresented: $viewModel.showNewRoomSheet) {
            NewRoomSheet(viewModel: viewModel)
                .frame(width: 560, height: 680)
        }
        .sheet(isPresented: $viewModel.showJoinSheet) {
            JoinRoomSheet(viewModel: viewModel)
                .frame(width: 420, height: 480)
        }
        #else
        .sheet(isPresented: $viewModel.showNewRoomSheet) {
            NewRoomSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showJoinSheet) {
            JoinRoomSheet(viewModel: viewModel)
        }
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
