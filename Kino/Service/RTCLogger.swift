//
//  RTCLogger.swift
//  Kino
//
//  Created by Nitesh on 07/11/24.
//

import OSLog

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
