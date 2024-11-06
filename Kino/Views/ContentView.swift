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



#Preview {
    ContentView()
}
