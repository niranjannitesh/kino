//
//  RTCVideo.swift
//  Kino
//
//  Created by Nitesh on 07/11/24.
//
import SwiftUI
import WebRTC
import AVFoundation

class VideoRenderer: NSView, RTCVideoRenderer {
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var videoSize: CGSize = .zero
    private let queue = DispatchQueue(label: "com.kino.videorenderer")
    private var contentMode: CALayerContentsGravity = .resizeAspect
    private var isMirrored: Bool = false

    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDisplayLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupDisplayLayer() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.black.cgColor
        
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.frame = self.bounds
        displayLayer.backgroundColor = NSColor.clear.cgColor
        
        self.layer?.addSublayer(displayLayer)
        self.displayLayer = displayLayer
        
        updateTransform()
    }
    
    
    private func updateTransform() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isMirrored {
            displayLayer?.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            // Adjust the anchor point to flip around the center
            displayLayer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        } else {
            displayLayer?.transform = CATransform3DIdentity
        }
        CATransaction.commit()
    }
    
    func setMirrored(_ mirrored: Bool) {
        isMirrored = mirrored
        updateTransform()
    }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer?.frame = bounds
        CATransaction.commit()
    }
    
    func setSize(_ size: CGSize) {
        queue.async {
            self.videoSize = size
            DispatchQueue.main.async {
                self.updateAspectRatio()
            }
        }
    }
    
    private func updateAspectRatio() {
        guard videoSize.width > 0 && videoSize.height > 0 else { return }
        
        let aspectRatio = videoSize.width / videoSize.height
        let viewAspectRatio = bounds.width / bounds.height
        
        var newFrame = bounds
        
        if aspectRatio > viewAspectRatio {
            // Video is wider than view
            newFrame.size.height = bounds.width / aspectRatio
            newFrame.origin.y = (bounds.height - newFrame.height) / 2
        } else {
            // Video is taller than view
            newFrame.size.width = bounds.height * aspectRatio
            newFrame.origin.x = (bounds.width - newFrame.width) / 2
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer?.frame = newFrame
        CATransaction.commit()
    }
    
    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame,
              let buffer = frame.buffer as? RTCCVPixelBuffer,
              let displayLayer = displayLayer else {
            return
        }
        
        let pixelBuffer = buffer.pixelBuffer
        var timing = CMTime(value: Int64(frame.timeStampNs), timescale: 1000000000)
        
        
        queue.async {
            // Create video info
            var videoInfo: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &videoInfo
            )
            
            guard let videoInfo = videoInfo else { return }
            
            // Create sample buffer
            var sampleBuffer: CMSampleBuffer?
            var samplingTiming = CMSampleTimingInfo(
                duration: CMTime.invalid,
                presentationTimeStamp: timing,
                decodeTimeStamp: CMTime.invalid
            )
            
            CMSampleBufferCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: videoInfo,
                sampleTiming: &samplingTiming,
                sampleBufferOut: &sampleBuffer
            )
            
            if let sampleBuffer = sampleBuffer {
                DispatchQueue.main.async {
                    self.displayLayer?.enqueue(sampleBuffer)
                    if self.displayLayer?.status == .failed {
                        self.displayLayer?.flush()
                    }
                }
            }
        }
    }
    
    func setContentMode(_ mode: CALayerContentsGravity) {
        contentMode = mode
        displayLayer?.videoGravity = AVLayerVideoGravity(rawValue: mode.rawValue)
        updateAspectRatio()
    }
}

struct RTCVideoView: NSViewRepresentable {
    let track: RTCVideoTrack
    var contentMode: CALayerContentsGravity = .resizeAspect
    var isMirrored: Bool = false

    
    func makeNSView(context: Context) -> VideoRenderer {
        let videoView = VideoRenderer(frame: .zero)
        videoView.setContentMode(contentMode)
        videoView.setMirrored(isMirrored)
        track.add(videoView)
        return videoView
    }
    
    func updateNSView(_ nsView: VideoRenderer, context: Context) {
        nsView.setContentMode(contentMode)
        nsView.setMirrored(isMirrored)
    }
}

// Updated video container view
struct VideoContainerView: NSViewRepresentable {
    let videoTrack: RTCVideoTrack
    @Binding var videoSize: CGSize
    
    func makeNSView(context: Context) -> VideoRenderer {
        let videoView = VideoRenderer(frame: .zero)
        videoTrack.add(videoView)
        return videoView
    }
    
    func updateNSView(_ nsView: VideoRenderer, context: Context) {
        // Handle updates if needed
    }
}
