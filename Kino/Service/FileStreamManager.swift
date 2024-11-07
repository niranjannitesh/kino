//
//  FileStreamManager.swift
//  Kino
//
//  Created by Nitesh on 07/11/24.
//

import SwiftUI

struct FileStreamMessage: Codable {
    enum MessageType: String, Codable {
        case metadata
        case chunk
        case end
    }
    
    let type: MessageType
    let fileName: String
    let fileSize: Int64
    let chunkIndex: Int
    let data: Data
    let timestamp: TimeInterval  // For synchronizing chunks
}

class FileStreamManager: ObservableObject {
    
    private class StreamingFile {
        let fileName: String
        let fileSize: Int64
        var receivedChunks: Set<Int> = []
        var isComplete: Bool = false
        var firstChunkReceived: Bool = false
        
        init(fileName: String, fileSize: Int64) {
            self.fileName = fileName
            self.fileSize = fileSize
        }
    }
    
    private let chunkSize = 65536 // 64KB chunks
    private var streamingFile: StreamingFile?
    private let webRTCService: WebRTCService
    private var outputFileHandle: FileHandle?
    private var outputURL: URL?
    
    @Published var isStreaming = false
    @Published var progress: Double = 0
    
    init(webRTCService: WebRTCService) {
        self.webRTCService = webRTCService
        setupTempFile()
    }
    
    private func setupTempFile() {
        // Create a unique temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueFilename = "stream_\(UUID().uuidString).mp4"
        outputURL = tempDir.appendingPathComponent(uniqueFilename)
        
        if let url = outputURL {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            outputFileHandle = try? FileHandle(forWritingTo: url)
        }
    }
    
    func startStreaming(url: URL) {
        let securedURL = url
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Get file size
            guard let fileSize = try? securedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                return
            }
            
            // Send metadata first
            DispatchQueue.main.async {
                self.isStreaming = true
                self.progress = 0
            }
            
            let metadataMessage = FileStreamMessage(
                type: .metadata,
                fileName: securedURL.lastPathComponent,
                fileSize: Int64(fileSize),
                chunkIndex: -1,
                data: Data(),
                timestamp: Date().timeIntervalSince1970
            )
            self.webRTCService.sendFileStream(metadataMessage)
            
            // Read and send file in chunks
            guard let data = try? Data(contentsOf: securedURL) else { return }
            let totalChunks = Int(ceil(Double(data.count) / Double(self.chunkSize)))
            
            for i in 0..<totalChunks {
                let start = i * self.chunkSize
                let end = min(start + self.chunkSize, data.count)
                let chunk = data[start..<end]
                
                let message = FileStreamMessage(
                    type: .chunk,
                    fileName: securedURL.lastPathComponent,
                    fileSize: Int64(fileSize),
                    chunkIndex: i,
                    data: chunk,
                    timestamp: Date().timeIntervalSince1970
                )
                self.webRTCService.sendFileStream(message)
                
                DispatchQueue.main.async {
                    self.progress = Double(i + 1) / Double(totalChunks)
                }
                
                // Small delay to prevent network congestion
                Thread.sleep(forTimeInterval: 0.001)
            }
            
            // Send end message
            let endMessage = FileStreamMessage(
                type: .end,
                fileName: securedURL.lastPathComponent,
                fileSize: Int64(fileSize),
                chunkIndex: totalChunks,
                data: Data(),
                timestamp: Date().timeIntervalSince1970
            )
            self.webRTCService.sendFileStream(endMessage)
            
            DispatchQueue.main.async {
                self.isStreaming = false
                self.progress = 1.0
            }
        }
    }
    
    func handleFileStream(_ message: FileStreamMessage) {
        switch message.type {
        case .metadata:
            streamingFile = StreamingFile(fileName: message.fileName, fileSize: message.fileSize)
            // Reset file
            try? outputFileHandle?.truncate(atOffset: 0)
            
            DispatchQueue.main.async {
                self.isStreaming = true
                self.progress = 0
            }
            
        case .chunk:
            guard let streamingFile = streamingFile else { return }
            
            // Write chunk at correct position
            let offset = UInt64(message.chunkIndex * chunkSize)
            try? outputFileHandle?.seek(toOffset: offset)
            try? outputFileHandle?.write(contentsOf: message.data)
            
            streamingFile.receivedChunks.insert(message.chunkIndex)
            
            DispatchQueue.main.async {
                self.progress = Double(streamingFile.receivedChunks.count) / Double(message.fileSize / Int64(self.chunkSize))
            }
            
            // Start playback after receiving initial chunks
            if !streamingFile.firstChunkReceived && streamingFile.receivedChunks.count > 5 {
                streamingFile.firstChunkReceived = true
                try? outputFileHandle?.synchronize()
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .streamingStarted,
                        object: nil,
                        userInfo: ["url": self.outputURL as Any]
                    )
                }
            }
            
        case .end:
            streamingFile?.isComplete = true
            try? outputFileHandle?.synchronize()
            
            DispatchQueue.main.async {
                self.isStreaming = false
                self.progress = 1.0
                NotificationCenter.default.post(name: .streamingEnded, object: nil)
            }
            
            // Setup new temp file for next stream
            setupTempFile()
        }
    }
}


extension Notification.Name {
    static let streamingStarted = Notification.Name("streamingStarted")
    static let streamingEnded = Notification.Name("streamingEnded")
}
