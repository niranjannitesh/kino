//
//  SignalingService.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//

import Foundation
import WebRTC

struct ParticipantInfo: Codable {
    let id: UUID
    let name: String
    let isHost: Bool
}

struct TrackInfo: Codable {
    let participantId: UUID
    let videoTrackId: String
    let audioTrackId: String
    let participantInfo: ParticipantInfo 
}

// MARK: - Signaling Models
struct SignalingMessage: Codable {
    enum MessageType: String, Codable {
        case offer
        case answer
        case iceCandidate
        case join
        case leave
        case trackInfo
    }
    
    let type: MessageType
    let roomCode: String
    let payload: SignalingPayload  // JSON encoded content
}

enum SignalingPayload: Codable {
    case sdp(SDPMessage)
    case ice(ICEMessage)
    case plain(String)
    case trackInfo(TrackInfo)

    
    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "sdp":
            let sdp = try container.decode(SDPMessage.self, forKey: .data)
            self = .sdp(sdp)
        case "ice":
            let ice = try container.decode(ICEMessage.self, forKey: .data)
            self = .ice(ice)
        case "trackInfo":
            let trackInfo = try container.decode(TrackInfo.self, forKey: .data)
            self = .trackInfo(trackInfo)
        default:
            let string = try container.decode(String.self, forKey: .data)
            self = .plain(string)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .sdp(let sdp):
            try container.encode("sdp", forKey: .type)
            try container.encode(sdp, forKey: .data)
        case .ice(let ice):
            try container.encode("ice", forKey: .type)
            try container.encode(ice, forKey: .data)
        case .trackInfo(let trackInfo):
            try container.encode("trackInfo", forKey: .type)
            try container.encode(trackInfo, forKey: .data)
        case .plain(let string):
            try container.encode("plain", forKey: .type)
            try container.encode(string, forKey: .data)
        }
    }
}

struct SDPMessage: Codable {
    let sdp: String
    let type: SDPType
}

enum SDPType: String, Codable {
    case offer
    case answer
}

struct ICEMessage: Codable {
    let candidate: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
}

// MARK: - Signaling Service
class SignalingService {
    private var webSocket: URLSessionWebSocketTask?
    weak var delegate: SignalingServiceDelegate?
    private let serverURL = "wss://kino-rooms.niranjannitesh.workers.dev"
    private var currentRoomCode: String?
    
    func connect(roomCode: String) {
        RTCLogger.shared.log("Signaling", "Connecting to room: \(roomCode)")
        currentRoomCode = roomCode
        
        guard let url = URL(string: "\(serverURL)/\(roomCode)") else {
            RTCLogger.shared.log("Signaling", "Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        
        let session = URLSession(configuration: .default)
        webSocket = session.webSocketTask(with: request)
        
        receiveMessage()
        webSocket?.resume()
        setupKeepAlive()
        
        // Send join message
        send(type: .join, roomCode: roomCode, payload: .plain("Joining room"))
    }
    
    private func setupKeepAlive() {
        // Send a ping every 30 seconds to keep the connection alive
        DispatchQueue.global().asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self = self,
                  let webSocket = self.webSocket,
                  webSocket.state == .running
            else { return }
            
            webSocket.sendPing { error in
                if let error = error {
                    RTCLogger.shared.log("Signaling", "Keep-alive failed: \(error)")
                    self.handleDisconnection()
                } else {
                    self.setupKeepAlive()
                }
            }
        }
    }
    
    private func handleDisconnection() {
        RTCLogger.shared.log("Signaling", "Handling disconnection")
        
        // Wait 5 seconds before attempting to reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self,
                  let roomCode = self.currentRoomCode
            else { return }
            
            RTCLogger.shared.log("Signaling", "Attempting to reconnect")
            self.connect(roomCode: roomCode)
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    RTCLogger.shared.log("Signaling", "Received: \(text)")
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage()
                
            case .failure(let error):
                RTCLogger.shared.log("Signaling", "WebSocket error: \(error)")
                self?.handleDisconnection()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        RTCLogger.shared.log("Signaling", "Received message: \(text)")
        
        guard let data = text.data(using: .utf8) else {
            RTCLogger.shared.log("Signaling", "Failed to convert message to data")
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String
            {
                
                if type == "clientCount" {
                    RTCLogger.shared.log("Signaling", "Received client count update")
                    return
                }
                
                if type == "trackInfo" {
                    if let payload = json["payload"] as? [String: Any],
                       let trackData = payload["data"] as? [String: Any],
                       let participantId = UUID(uuidString: trackData["participantId"] as? String ?? ""),
                       let videoTrackId = trackData["videoTrackId"] as? String,
                       let audioTrackId = trackData["audioTrackId"] as? String,
                       let participantData = trackData["participantInfo"] as? [String: Any],
                       let name = participantData["name"] as? String,
                       let isHost = participantData["isHost"] as? Bool {
                        
                        RTCLogger.shared.log("Signaling", "Processing forwarded track info")
                        let participantInfo = ParticipantInfo(
                                                id: participantId,
                                                name: name,
                                                isHost: isHost
                                            )
                        
                        let trackInfo = TrackInfo(
                            participantId: participantId,
                            videoTrackId: videoTrackId,
                            audioTrackId: audioTrackId,
                            participantInfo: participantInfo
                        )
                        
                        delegate?.signaling(didReceiveTrackInfo: trackInfo, for: currentRoomCode!)
                    }
                } else if type == "offer" {
                    if let payload = json["payload"] as? [String: Any],
                       let sdpData = payload["data"] as? [String: Any],
                       let sdp = sdpData["sdp"] as? String
                    {
                        RTCLogger.shared.log("Signaling", "Processing forwarded offer")
                        let sdpMessage = SDPMessage(sdp: sdp, type: .offer)
                        delegate?.signaling(didReceiveOffer: sdpMessage, for: currentRoomCode!)
                    }
                } else if type == "answer" {  // Add answer handling
                    if let payload = json["payload"] as? [String: Any],
                       let sdpData = payload["data"] as? [String: Any],
                       let sdp = sdpData["sdp"] as? String
                    {
                        RTCLogger.shared.log("Signaling", "Processing forwarded answer")
                        let sdpMessage = SDPMessage(sdp: sdp, type: .answer)
                        delegate?.signaling(didReceiveAnswer: sdpMessage, for: currentRoomCode!)
                    }
                } else if type == "iceCandidate" {
                    if let payload = json["payload"] as? [String: Any],
                       let iceData = payload["data"] as? [String: Any],
                       let candidate = iceData["candidate"] as? String,
                       let sdpMLineIndex = iceData["sdpMLineIndex"] as? Int32,
                       let sdpMid = iceData["sdpMid"] as? String
                    {
                        RTCLogger.shared.log("Signaling", "Processing forwarded ICE candidate")
                        let iceMessage = ICEMessage(
                            candidate: candidate,
                            sdpMLineIndex: sdpMLineIndex,
                            sdpMid: sdpMid
                        )
                        delegate?.signaling(didReceiveIceCandidate: iceMessage, for: currentRoomCode!)
                    }
                } else if type == "join" {
                    if let payload = json["payload"] as? [String: Any],
                       let data = payload["data"] as? String {
                        RTCLogger.shared.log("Signaling", "Processing join message")
                        delegate?.signaling(didReceiveJoin: data, for: currentRoomCode!)
                    }
                }
            }
        } catch {
            RTCLogger.shared.log("Signaling", "Failed to parse message: \(error)")
        }
    }
    
    func send(type: SignalingMessage.MessageType, roomCode: String, payload: SignalingPayload) {
        let message = SignalingMessage(type: type, roomCode: roomCode, payload: payload)
        guard let data = try? JSONEncoder().encode(message),
              let string = String(data: data, encoding: .utf8)
        else {
            print("Failed to encode message")
            return
        }
        
        webSocket?.send(.string(string)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
}

protocol SignalingServiceDelegate: AnyObject {
    func signaling(didReceiveOffer: SDPMessage, for roomCode: String)
    func signaling(didReceiveAnswer: SDPMessage, for roomCode: String)
    func signaling(didReceiveIceCandidate: ICEMessage, for roomCode: String)
    func signaling(didReceiveJoin: String, for roomCode: String)
    func signaling(didReceiveTrackInfo: TrackInfo, for roomCode: String)
}
