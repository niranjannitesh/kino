//
//  RTC.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//
import OSLog
import WebRTC

// Custom logger for WebRTC events
class RTCLogger {
    static let shared = RTCLogger()
    private let logger = Logger(subsystem: "com.kino.app", category: "WebRTC")
//    private let fileLogger: FileHandle?
    
//    init() {
//        // Create unique log file for this instance
//        let fileName = "kino_webrtc_\(UUID().uuidString).log"
//        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let logPath = documentsPath.appendingPathComponent(fileName)
//        
//        FileManager.default.createFile(atPath: logPath.path, contents: nil)
//        fileLogger = try? FileHandle(forWritingTo: logPath)
//        
//        log("Logger", "Logging to file: \(logPath.path)")
//    }
    
    func log(_ type: String, _ message: String) {
//        let timestamp = ISO8601DateFormatter().string(from: Date())
//        let logMessage = "[\(timestamp)] [\(type)] \(message)\n"
        
#if DEBUG
        logger.debug("[\(type)] \(message)")
#endif
        
//        fileLogger?.write(logMessage.data(using: .utf8) ?? Data())
    }
    
//    deinit {
//        fileLogger?.closeFile()
//    }
}

class WebRTCService: NSObject, ObservableObject {
    private let instanceId = UUID().uuidString
    
    private let factory: RTCPeerConnectionFactory
    private let config: RTCConfiguration
    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    
    private var pendingICECandidates: [RTCIceCandidate] = []
    private var isInitiator = false
    
    private let signaling = SignalingService()
    private var currentRoomCode: String?
    
    var delegate: WebRTCServiceDelegate?
    
    // Published properties for UI updates
    @Published var connectionState: RTCPeerConnectionState = .new
    @Published var isConnected: Bool = false
    @Published var dataChannelState: RTCDataChannelState = .closed
    
    override init() {
        RTCLogger.shared.log("Init", "Initializing WebRTC Service instance: \(instanceId)")
        
        // Initialize WebRTC
        RTCInitializeSSL()
        RTCInitFieldTrialDictionary([:])
        factory = RTCPeerConnectionFactory()
        
        // Configure ICE servers
        let iceServer = RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        config = RTCConfiguration()
        config.iceServers = [iceServer]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        super.init()
        
        signaling.delegate = self
        
        let iceServersStr = config.iceServers.flatMap { $0.urlStrings }.joined(separator: ", ")
        RTCLogger.shared.log("Init", "WebRTC Service initialized with ICE servers: \(iceServersStr)")
    }
    
    deinit {
        RTCLogger.shared.log("Deinit", "Cleaning up WebRTC Service")
        RTCCleanupSSL()
    }
    
    // Create a room as host
    func createRoom() async throws -> String {
        RTCLogger.shared.log("Room", "Creating new room")
        
        isInitiator = true
        
        // Generate room code
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let length = 5
        let randomString = (0..<length).map { _ in
            String(characters.randomElement()!)
        }.joined()
        let roomCode = "KINO-\(randomString)"
        currentRoomCode = roomCode
        
        try await setupPeerConnection()
        signaling.connect(roomCode: roomCode)
        
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        
        if let peerConnection = peerConnection {
            Task {
                do {
                    let offer = try await createOffer()
                    try await peerConnection.setLocalDescription(offer)
                    sendOffer(offer)
                } catch {
                    RTCLogger.shared.log("SDP", "Failed to create and send offer: \(error)")
                }
            }
        } else {
            RTCLogger.shared.log("Room", "Failed to create peer connection")
        }
        
        RTCLogger.shared.log("Room", "Created room with code: \(roomCode)")
        return roomCode
    }
    
    private func setupPeerConnection() async throws {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "false",
            ],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        peerConnection = factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
        
        if isInitiator {
            RTCLogger.shared.log("Setup", "Creating data channel as initiator")
            let dataChannelConfig = RTCDataChannelConfiguration()
            dataChannelConfig.isOrdered = true
            dataChannelConfig.isNegotiated = false  // Ensure this is false
            dataChannelConfig.channelId = -1  // Let WebRTC assign the ID
            
            guard let peerConnection = peerConnection else {
                throw WebRTCError.peerConnectionFailed
            }
            
            guard
                let channel = peerConnection.dataChannel(
                    forLabel: "KinoSync",
                    configuration: dataChannelConfig
                )
            else {
                throw WebRTCError.dataChannelFailed
            }
            
            dataChannel = channel
            dataChannel?.delegate = self
            
            RTCLogger.shared.log(
                "DataChannel",
        """
        Created data channel:
        Label: \(channel.label)
        State: \(channel.readyState.rawValue)
        IsOrdered: \(channel.isOrdered)
        Delegate set: \(channel.delegate != nil)
        """)
        } else {
            RTCLogger.shared.log("Setup", "Waiting for data channel as receiver")
        }
        
    }
    
    private func createOffer() async throws -> RTCSessionDescription {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "false",
            ],
            optionalConstraints: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            peerConnection?.offer(for: constraints) { sdp, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sdp = sdp {
                    RTCLogger.shared.log("SDP", "Created offer: \(sdp.sdp)")
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: WebRTCError.sdpCreationFailed)
                }
            }
        }
    }
    
    private func sendOffer(_ offer: RTCSessionDescription) {
        guard let roomCode = currentRoomCode else { return }
        RTCLogger.shared.log("SDP", "Sending offer")
        
        let sdpMessage = SDPMessage(sdp: offer.sdp, type: .offer)
        signaling.send(type: .offer, roomCode: roomCode, payload: .sdp(sdpMessage))
    }
    
    private func sendAnswer(_ answer: RTCSessionDescription) {
        guard let roomCode = currentRoomCode else { return }
        RTCLogger.shared.log("SDP", "Sending answer")
        
        let sdpMessage = SDPMessage(sdp: answer.sdp, type: .answer)
        signaling.send(type: .answer, roomCode: roomCode, payload: .sdp(sdpMessage))
    }
    
    private func sendIceCandidate(_ candidate: RTCIceCandidate) {
        guard let roomCode = currentRoomCode else { return }
        RTCLogger.shared.log("ICE", "Sending ICE candidate")
        
        let iceMessage = ICEMessage(
            candidate: candidate.sdp,
            sdpMLineIndex: candidate.sdpMLineIndex,
            sdpMid: candidate.sdpMid
        )
        signaling.send(type: .iceCandidate, roomCode: roomCode, payload: .ice(iceMessage))
    }
    
    func handlePeerJoined() {
        RTCLogger.shared.log("WebRTC", "New peer joined, creating offer")
        
        guard isInitiator else {
            RTCLogger.shared.log("WebRTC", "Not initiator, skipping offer creation")
            return
        }
        
        Task {
            do {
                let offer = try await createOffer()
                try await peerConnection?.setLocalDescription(offer)
                sendOffer(offer)
            } catch {
                RTCLogger.shared.log("WebRTC", "Failed to create and send offer: \(error)")
            }
        }
    }
    
    private func handlePendingCandidates() {
        guard let peerConnection = peerConnection,
              peerConnection.remoteDescription != nil
        else { return }
        
        RTCLogger.shared.log("ICE", "Processing \(pendingICECandidates.count) pending candidates")
        
        pendingICECandidates.forEach { candidate in
            peerConnection.add(candidate)
        }
        pendingICECandidates.removeAll()
    }
    
    // Join existing room
    func joinRoom(code: String) async throws {
        RTCLogger.shared.log("Room", "Joining room with code: \(code)")
        isInitiator = false
        currentRoomCode = code
        
        try await setupPeerConnection()
        guard let peerConnection = peerConnection else {
            throw WebRTCError.peerConnectionFailed
        }
        signaling.connect(roomCode: code)
        
        RTCLogger.shared.log("DataChannel", "Initial state: \(dataChannel?.readyState.rawValue ?? -1)")
    }
    
    // Send player state through data channel
    func sendPlayerState(_ state: PlayerState) {
        guard let dataChannel = dataChannel else {
            RTCLogger.shared.log("DataChannel", "Cannot send state: data channel is nil")
            return
        }
        
        guard dataChannel.readyState == .open else {
            RTCLogger.shared.log(
                "DataChannel",
                "Cannot send state: data channel not open (state: \(dataChannel.readyState.rawValue))")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(state)
            let buffer = RTCDataBuffer(data: data, isBinary: true)
            dataChannel.sendData(buffer)
            RTCLogger.shared.log(
                "DataChannel", "Sent player isPlaying: \(state.isPlaying) at position \(state.position)")
        } catch {
            RTCLogger.shared.log("DataChannel", "Failed to send player state: \(error)")
        }
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCService: RTCPeerConnectionDelegate {
    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState
    ) {
        RTCLogger.shared.log("PeerConnection", "Signaling state changed to: \(stateChanged.rawValue)")
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        RTCLogger.shared.log("PeerConnection", "Negotiation required")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange state: RTCPeerConnectionState)
    {
        DispatchQueue.main.async {
            self.connectionState = state
            self.isConnected = (state == .connected)
        }
        RTCLogger.shared.log("PeerConnection", "Connection state changed to: \(state.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        RTCLogger.shared.log("PeerConnection", "Stream added: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        RTCLogger.shared.log("PeerConnection", "Stream removed: \(stream.streamId)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        RTCLogger.shared.log("ICE", "Generated candidate: \(candidate.sdp)")
        sendIceCandidate(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate])
    {
        RTCLogger.shared.log("ICE", "Removed \(candidates.count) candidates")
    }
    
    func peerConnection(
        _ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState
    ) {
        RTCLogger.shared.log("ICE", "Connection state changed to: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState)
    {
        RTCLogger.shared.log("ICE", "Gathering state changed to: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        RTCLogger.shared.log(
            "DataChannel",
      """
      Received data channel:
      Label: \(dataChannel.label)
      State: \(dataChannel.readyState.rawValue)
      IsOrdered: \(dataChannel.isOrdered)
      """)
        self.dataChannel = dataChannel
        dataChannel.delegate = self
        RTCLogger.shared.log("DataChannel", "Delegate set for received channel")
    }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCService: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        DispatchQueue.main.async {
            self.dataChannelState = dataChannel.readyState
            self.isConnected = (dataChannel.readyState == .open)
        }
        
        RTCLogger.shared.log(
            "DataChannel",
      """
      State changed to: \(dataChannel.readyState.rawValue)
      Label: \(dataChannel.label)
      IsOrdered: \(dataChannel.isOrdered)
      ChannelId: \(dataChannel.channelId)
      BufferedAmount: \(dataChannel.bufferedAmount)
      MaxRetransmits: \(String(describing: dataChannel.maxRetransmits))
      IsNegotiated: \(dataChannel.isNegotiated)
      """)
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let data = try? JSONDecoder().decode(PlayerState.self, from: buffer.data) {
            RTCLogger.shared.log(
                "DataChannel", "Received player is Playing: \(data.isPlaying) at position \(data.position)"
            )
            DispatchQueue.main.async {
                self.delegate?.webRTC(didReceivePlayerState: data)
            }
        } else {
            RTCLogger.shared.log("DataChannel", "Received message but failed to decode")
        }
    }
}

extension WebRTCService: SignalingServiceDelegate {
    func signaling(didReceiveOffer sdpMessage: SDPMessage, for roomCode: String) {
        RTCLogger.shared.log("WebRTC", "Received offer for room: \(roomCode)")
        
        Task {
            do {
                if peerConnection == nil {
                    RTCLogger.shared.log("WebRTC", "Setting up peer connection for receiver")
                    try await setupPeerConnection()
                }
                
                guard let peerConnection = peerConnection else {
                    throw WebRTCError.peerConnectionFailed
                }
                
                let sdp = RTCSessionDescription(type: .offer, sdp: sdpMessage.sdp)
                RTCLogger.shared.log("WebRTC", "Setting remote description")
                try await peerConnection.setRemoteDescription(sdp)
                
                RTCLogger.shared.log("WebRTC", "Creating answer")
                let constraints = RTCMediaConstraints(
                    mandatoryConstraints: [
                        "OfferToReceiveAudio": "false",
                        "OfferToReceiveVideo": "false",
                    ],
                    optionalConstraints: nil
                )
                let answer = try await peerConnection.answer(for: constraints)
                
                RTCLogger.shared.log("WebRTC", "Setting local description")
                try await peerConnection.setLocalDescription(answer)
                
                RTCLogger.shared.log("WebRTC", "Sending answer")
                signaling.send(
                    type: .answer,
                    roomCode: roomCode,
                    payload: .sdp(SDPMessage(sdp: answer.sdp, type: .answer))
                )
                handlePendingCandidates()
            } catch {
                RTCLogger.shared.log("WebRTC", "Error processing offer: \(error)")
            }
        }
    }
    
    func signaling(didReceiveAnswer sdpMessage: SDPMessage, for roomCode: String) {
        RTCLogger.shared.log("SDP", "Processing received answer")
        guard let peerConnection = peerConnection else { return }
        
        Task {
            do {
                let sdp = RTCSessionDescription(type: .answer, sdp: sdpMessage.sdp)
                RTCLogger.shared.log("SDP", "Setting remote description (answer)")
                try await peerConnection.setRemoteDescription(sdp)
                RTCLogger.shared.log("SDP", "Remote description set successfully")
                handlePendingCandidates()
            } catch {
                RTCLogger.shared.log("SDP", "Error handling answer: \(error)")
            }
        }
    }
    
    func signaling(didReceiveIceCandidate iceMessage: ICEMessage, for roomCode: String) {
        RTCLogger.shared.log("ICE", "Received ICE candidate")
        
        let candidate = RTCIceCandidate(
            sdp: iceMessage.candidate,
            sdpMLineIndex: iceMessage.sdpMLineIndex,
            sdpMid: iceMessage.sdpMid
        )
        
        if peerConnection?.remoteDescription == nil {
            pendingICECandidates.append(candidate)
            RTCLogger.shared.log("ICE", "Stored pending ICE candidate")
        } else {
            peerConnection?.add(candidate)
            RTCLogger.shared.log("ICE", "Added ICE candidate immediately")
        }
    }
    
    func signaling(didReceiveJoin message: String, for roomCode: String) {
        RTCLogger.shared.log("WebRTC", "Received join message: \(message)")
        handlePeerJoined()
    }
}

// MARK: - Custom Errors
enum WebRTCError: Error {
    case peerConnectionFailed
    case dataChannelFailed
    case sdpCreationFailed
    case invalidState
}

protocol WebRTCServiceDelegate {
    func webRTC(didReceivePlayerState state: PlayerState)
}
