//
//  RTC.swift
//  Kino
//
//  Created by Nitesh on 06/11/24.
//
import OSLog
import WebRTC

class WebRTCService: NSObject, ObservableObject {
  private let instanceId = UUID().uuidString

  private let factory: RTCPeerConnectionFactory
  private let config: RTCConfiguration
  private var peerConnection: RTCPeerConnection?
  private var dataChannel: RTCDataChannel?

  private var fileChannel: RTCDataChannel?

  private var pendingICECandidates: [RTCIceCandidate] = []
  private var isInitiator = false

  private let signaling = SignalingService()
  private var currentRoomCode: String?

  private var localVideoTrack: RTCVideoTrack?
  private var localAudioTrack: RTCAudioTrack?
  private var remoteVideoTracks: [String: RTCVideoTrack] = [:]
  private var remoteAudioTracks: [String: RTCAudioTrack] = [:]

  private var trackToParticipant: [String: UUID] = [:]
  private var participantToTrack: [UUID: String] = [:]
  private var localParticipantId: UUID = UUID()

  private var remoteParticipantInfo: [UUID: ParticipantInfo] = [:]

  private var videoCapturer: RTCCameraVideoCapturer?

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

    videoCapturer?.stopCapture()
    videoCapturer = nil

    // Cleanup tracks
    localVideoTrack?.isEnabled = false
    localAudioTrack?.isEnabled = false

    // Cleanup peer connection
    if let peerConnection = peerConnection {
      peerConnection.close()
    }
    peerConnection = nil

    // Reset state
    isInitiator = false
    currentRoomCode = nil
    pendingICECandidates.removeAll()
    remoteVideoTracks.removeAll()
    remoteAudioTracks.removeAll()
    trackToParticipant.removeAll()
    participantToTrack.removeAll()

    // Cleanup data channels
    dataChannel = nil
    fileChannel = nil

    RTCLogger.shared.log("Cleanup", "WebRTC cleanup completed")
  }

  private var displayName: String = ""

  func setDisplayName(_ name: String) {
    self.displayName = name
  }

  func createRoom(displayName: String) async throws -> String {
    RTCLogger.shared.log("Room", "Creating new room")

    self.displayName = displayName

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

  private func setupLocalPreview() {
    guard let track = localVideoTrack else {
      RTCLogger.shared.log("Video", "No local video track available for preview")
      return
    }

    DispatchQueue.main.async {
      let localParticipant = Participant(
        id: self.localParticipantId,
        name: self.isInitiator ? "\(self.displayName) (Host)" : "\(self.displayName)",
        status: self.isInitiator ? "Host" : "Connected",
        avatar: self.displayName.first!.uppercased(),
        isAudioEnabled: true,
        videoTrack: track,
        isLocal: true
      )

      RTCLogger.shared.log(
        "Video", "Setting up local preview for participant: \(localParticipant.id)")
      self.delegate?.webRTC(didReceiveParticipantInfo: localParticipant)
      self.delegate?.webRTC(didReceiveVideoTrack: track, forParticipant: self.localParticipantId)
    }
  }

  private func exchangeTrackInfo() {
    RTCLogger.shared.log("WebRTC", "Exchanging track info")
    guard let roomCode = currentRoomCode else { return }

    let participantInfo = ParticipantInfo(
      id: localParticipantId,
      name: displayName,
      isHost: isInitiator
    )

    // Send track info for local tracks
    let trackInfo = TrackInfo(
      participantId: localParticipantId,
      videoTrackId: localVideoTrack?.trackId ?? "",
      audioTrackId: localAudioTrack?.trackId ?? "",
      participantInfo: participantInfo
    )

    signaling.send(
      type: .trackInfo,
      roomCode: roomCode,
      payload: .trackInfo(trackInfo)
    )

    // Also create local participant
    DispatchQueue.main.async {
      let localParticipant = Participant(
        id: self.localParticipantId,
        name: self.isInitiator ? "\(self.displayName) (Host)" : "\(self.displayName)",
        status: self.isInitiator ? "Host" : "Connected",
        avatar: self.displayName.first!.uppercased(),
        isAudioEnabled: true,
        videoTrack: self.localVideoTrack,
        isLocal: true
      )
      self.delegate?.webRTC(didReceiveParticipantInfo: localParticipant)
    }
  }

  private func setupPeerConnection() async throws {
    let constraints = RTCMediaConstraints(
      mandatoryConstraints: [
        "OfferToReceiveAudio": "true",
        "OfferToReceiveVideo": "true",
      ],
      optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
    )

    peerConnection = factory.peerConnection(
      with: config,
      constraints: constraints,
      delegate: self
    )

    guard let peerConnection = peerConnection else {
      throw WebRTCError.peerConnectionFailed
    }

    do {
      // Video setup
      let videoSource = factory.videoSource()
      videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)

      guard let device = AVCaptureDevice.default(for: .video) else {
        RTCLogger.shared.log("Media", "No camera available")
        throw WebRTCError.noCamera
      }

      let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
      guard let format = formats.first else {
        throw WebRTCError.noVideoFormat
      }

      try await videoCapturer?.startCapture(
        with: device,
        format: format,
        fps: 30
      )

      let videoTrackId = "video-\(localParticipantId.uuidString)"
      localVideoTrack = factory.videoTrack(with: videoSource, trackId: videoTrackId)

      if let track = localVideoTrack {
        trackToParticipant[track.trackId] = localParticipantId
        participantToTrack[localParticipantId] = track.trackId
      }

      // Audio setup
      let audioConstraints = RTCMediaConstraints(
        mandatoryConstraints: nil, optionalConstraints: nil)
      let audioSource = factory.audioSource(with: audioConstraints)
      let audioTrackId = "audio-\(localParticipantId.uuidString)"
      localAudioTrack = factory.audioTrack(with: audioSource, trackId: audioTrackId)

      // Add tracks to peer connection
      if let track = localVideoTrack {
        setupLocalPreview()

        peerConnection.add(track, streamIds: ["stream0"])
        RTCLogger.shared.log("Media", "Added local video track: \(track.trackId)")
      }

      if let audioTrack = localAudioTrack {
        peerConnection.add(audioTrack, streamIds: ["stream0"])
        RTCLogger.shared.log("Media", "Added local audio track")
      }
    } catch {
      RTCLogger.shared.log("Media", "Failed to setup media tracks: \(error)")
      throw error
    }

    if isInitiator {
      let dataChannelConfig = RTCDataChannelConfiguration()
      dataChannelConfig.isOrdered = true
      dataChannelConfig.isNegotiated = false  // Ensure this is false
      dataChannelConfig.channelId = -1  // Let WebRTC assign the ID

      dataChannel = peerConnection.dataChannel(
        forLabel: "KinoSync",
        configuration: dataChannelConfig
      )
      dataChannel?.delegate = self

      let config = RTCDataChannelConfiguration()
      config.isOrdered = true
      config.maxRetransmits = 0  // Reliable channel
      config.channelId = 10  // Use different ID from main channel
      fileChannel = peerConnection.dataChannel(forLabel: "fileChannel", configuration: config)
      fileChannel?.delegate = self

      RTCLogger.shared.log(
        "Setup",
        """
        Created channels:
        Sync: \(dataChannel!.label) (State: \(dataChannel!.readyState.rawValue))
        File: \(fileChannel!.label) (State: \(fileChannel!.readyState.rawValue))
        """
      )
    } else {
      RTCLogger.shared.log("Setup", "Waiting for data channel as receiver")
    }

  }

  private func createOffer() async throws -> RTCSessionDescription {
    let constraints = RTCMediaConstraints(
      mandatoryConstraints: [
        "OfferToReceiveAudio": "true",
        "OfferToReceiveVideo": "true",
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

    if let roomCode = currentRoomCode {
      let trackInfo = TrackInfo(
        participantId: localParticipantId,
        videoTrackId: localVideoTrack?.trackId ?? "pending-video-\(localParticipantId.uuidString)",
        audioTrackId: localAudioTrack?.trackId ?? "pending-audio-\(localParticipantId.uuidString)",
        participantInfo: ParticipantInfo(
          id: localParticipantId,
          name: displayName,
          isHost: true
        )
      )

      signaling.send(
        type: .trackInfo,
        roomCode: roomCode,
        payload: .trackInfo(trackInfo)
      )
    }

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
  func joinRoom(code: String, displayName: String) async throws {
    RTCLogger.shared.log("Room", "Joining room with code: \(code)")
    isInitiator = false
    currentRoomCode = code
    self.displayName = displayName

    try await setupPeerConnection()
    guard let peerConnection = peerConnection else {
      throw WebRTCError.peerConnectionFailed
    }
    signaling.connect(roomCode: code)

    RTCLogger.shared.log("DataChannel", "Initial state: \(dataChannel?.readyState.rawValue ?? -1)")
  }

  // Send player state through data channel
  func sendPlayerState(_ state: PlayerState) {

    guard let channel = dataChannel, channel.label == "KinoSync" else {
      RTCLogger.shared.log("PlayerSync", "Sync channel not available")
      return
    }

    guard channel.readyState == .open else {
      RTCLogger.shared.log(
        "DataChannel",
        "Cannot send state: data channel not open (state: \(channel.readyState.rawValue))")
      return
    }

    do {
      let data = try JSONEncoder().encode(state)
      let buffer = RTCDataBuffer(data: data, isBinary: true)
      channel.sendData(buffer)
      RTCLogger.shared.log(
        "DataChannel", "Sent player isPlaying: \(state.isPlaying) at position \(state.position)")
    } catch {
      RTCLogger.shared.log("DataChannel", "Failed to send player state: \(error)")
    }
  }

  private func getParticipantId(forTrack track: RTCVideoTrack) -> UUID? {
    // For local track
    if track === localVideoTrack {
      return localParticipantId
    }

    // For remote tracks
    return trackToParticipant[track.trackId]
  }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCService: RTCPeerConnectionDelegate {
  func peerConnection(
    _ peerConnection: RTCPeerConnection, didChange state: RTCSignalingState
  ) {
    DispatchQueue.main.async {
      self.exchangeTrackInfo()
    }
    RTCLogger.shared.log("PeerConnection", "Signaling state changed to: \(state.rawValue)")
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
        DispatchQueue.main.async {
            stream.videoTracks.forEach { track in
                self.remoteVideoTracks[track.trackId] = track
                if let participantId = self.getParticipantId(forTrack: track) {
                    self.delegate?.webRTC(didReceiveVideoTrack: track, forParticipant: participantId)
                } else {
                    let tempParticipantId = UUID()
                    RTCLogger.shared.log(
                        "Video", "Creating new participant for unmapped track: \(tempParticipantId)")

                    self.trackToParticipant[track.trackId] = tempParticipantId
                    
                    // Get participant info from stored remote participant info
                    let participantInfo = self.remoteParticipantInfo[tempParticipantId]
                    let remoteName = participantInfo?.name ?? "Unknown Peer"
                    let isRemoteHost = participantInfo?.isHost ?? false

                    let participant = Participant(
                        id: tempParticipantId,
                        name: isRemoteHost ? "\(remoteName) (Host)" : remoteName,
                        status: isRemoteHost ? "Host" : "Connected",
                        avatar: remoteName.first?.uppercased() ?? "?",
                        isAudioEnabled: false,
                        videoTrack: track,
                        isLocal: false
                    )
                    self.delegate?.webRTC(didReceiveParticipantInfo: participant)
                    self.delegate?.webRTC(didReceiveVideoTrack: track, forParticipant: tempParticipantId)
                }
            }

            stream.audioTracks.forEach { track in
                self.remoteAudioTracks[track.trackId] = track

                if let participantId = self.trackToParticipant[
                    track.trackId.replacingOccurrences(of: "video", with: "audio")]
                {
                    self.delegate?.webRTC(didReceiveAudioTrack: track, forParticipant: participantId)
                } else {
                    RTCLogger.shared.log(
                        "WebRTC", "Received track with no participant mapping: \(track.trackId)")
                }
            }
        }
    }

  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    RTCLogger.shared.log("PeerConnection", "Stream removed: \(stream.streamId)")
    DispatchQueue.main.async {
      stream.videoTracks.forEach { track in
        if let participantId = self.getParticipantId(forTrack: track) {
          self.delegate?.webRTC(didRemoveVideoTrack: track, forParticipant: participantId)
        }
        self.remoteVideoTracks.removeValue(forKey: track.trackId)
      }
    }
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

    switch dataChannel.label {
    case "KinoSync":
      self.dataChannel = dataChannel
    case "fileChannel":
      self.fileChannel = dataChannel
    default:
      RTCLogger.shared.log("DataChannel", "Unknown channel label: \(dataChannel.label)")
      return
    }

    dataChannel.delegate = self
  }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCService: RTCDataChannelDelegate {
  func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
    DispatchQueue.main.async {
      if dataChannel.label == "KinoSync" {
        self.dataChannelState = dataChannel.readyState
        self.isConnected = (dataChannel.readyState == .open)
      } else if dataChannel.label == "KinoFileStream" {
        self.isConnected = (dataChannel.readyState == .open)
      }
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
    RTCLogger.shared.log(
      "DataChannel",
      "Received message for \(dataChannel.label): \(buffer.data.count) bytes"
    )

    switch dataChannel.label {
    case "KinoSync":
      guard let state = try? JSONDecoder().decode(PlayerState.self, from: buffer.data) else {
        RTCLogger.shared.log("DataChannel", "Failed to decode player state")
        return
      }

      RTCLogger.shared.log(
        "DataChannel",
        "Decoded player state - Playing: \(state.isPlaying) Position: \(state.position)"
      )

      DispatchQueue.main.async {
        self.delegate?.webRTC(didReceivePlayerState: state)
      }
    case "fileChannel":
      guard let message = try? JSONDecoder().decode(FileStreamMessage.self, from: buffer.data)
      else {
        RTCLogger.shared.log("DataChannel", "Failed to decode file message")
        return
      }
      DispatchQueue.main.async {
        self.delegate?.webRTC(didReceiveFileStream: message)
      }
    default:
      RTCLogger.shared.log("DataChannel", "Unknown channel: \(dataChannel.label)")
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
            "OfferToReceiveAudio": "true",
            "OfferToReceiveVideo": "true",
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
  func signaling(didReceiveTrackInfo trackInfo: TrackInfo, for roomCode: String) {
    RTCLogger.shared.log(
      "WebRTC",
      """
      Received track info:
      Participant: \(trackInfo.participantId)
      Video Track: \(trackInfo.videoTrackId)
      Audio Track: \(trackInfo.audioTrackId)
      """
    )

    guard trackInfo.participantId != localParticipantId else {
      RTCLogger.shared.log("WebRTC", "Skipping own track info")
      return
    }

    remoteParticipantInfo[trackInfo.participantId] = trackInfo.participantInfo

    if !trackInfo.videoTrackId.isEmpty {
      trackToParticipant[trackInfo.videoTrackId] = trackInfo.participantId
      participantToTrack[trackInfo.participantId] = trackInfo.videoTrackId
    }

    if !trackInfo.audioTrackId.isEmpty {
      trackToParticipant[trackInfo.audioTrackId] = trackInfo.participantId
    }

    //        let participant = Participant(
    //            id: trackInfo.participantId,
    //            name: self.isInitiator ? "Peer" : "Host",
    //            status: "Connected",
    //            avatar: isInitiator ? "H": "P",
    //            isAudioEnabled: false,  // Will be updated when audio track arrives
    //            videoTrack: nil  // Will be updated when video track arrives
    //        )
    //
    //        DispatchQueue.main.async {
    //            self.delegate?.webRTC(didReceiveParticipantInfo: participant)
    //        }

    if let videoTrack = remoteVideoTracks[trackInfo.videoTrackId] {
      DispatchQueue.main.async {
        self.delegate?.webRTC(
          didReceiveVideoTrack: videoTrack, forParticipant: trackInfo.participantId)
      }
    }

    if let audioTrack = remoteAudioTracks[trackInfo.audioTrackId] {
      DispatchQueue.main.async {
        self.delegate?.webRTC(
          didReceiveAudioTrack: audioTrack, forParticipant: trackInfo.participantId)
      }
    }
  }
}

extension WebRTCService {
  func sendFileStream(_ message: FileStreamMessage) {
    guard let data = try? JSONEncoder().encode(message) else { return }

    // Convert to RTCDataBuffer
    let buffer = RTCDataBuffer(data: data, isBinary: true)

    // Send using the WebRTC data channel
    fileChannel?.sendData(buffer)
  }
}

// MARK: - Custom Errors
enum WebRTCError: Error {
  case peerConnectionFailed
  case dataChannelFailed
  case sdpCreationFailed
  case invalidState
  case noVideoFormat
  case noCamera
}

protocol WebRTCServiceDelegate {
  func webRTC(didReceivePlayerState state: PlayerState)

  func webRTC(didReceiveFileStream message: FileStreamMessage)

  func webRTC(didReceiveVideoTrack track: RTCVideoTrack, forParticipant id: UUID)
  func webRTC(didRemoveVideoTrack track: RTCVideoTrack, forParticipant id: UUID)
  func webRTC(didReceiveAudioTrack track: RTCAudioTrack, forParticipant id: UUID)
  func webRTC(didRemoveAudioTrack track: RTCAudioTrack, forParticipant id: UUID)
  func webRTC(didReceiveParticipantInfo participant: Participant)
}
