//
//  VideoCompositor.swift
//  VideoLab
//
//  Created by Bear on 02/19/2020.
//  Copyright (c) 2020 Chocolate. All rights reserved.
//

import AVFoundation

open class VLVideoCompositor: NSObject, AVVideoCompositing {
    private var renderingQueue = DispatchQueue(label: "com.studio.VideoLab.renderingqueue")
    private var renderContextQueue = DispatchQueue(label: "com.studio.VideoLab.rendercontextqueue")
    private var renderContext: AVVideoCompositionRenderContext?
    private var shouldCancelAllRequests = false
    
    private let layerCompositor = LayerCompositor()
    
    // MARK: - AVVideoCompositing
    public var sourcePixelBufferAttributes: [String : Any]? =
        [String(kCVPixelBufferPixelFormatTypeKey): [Int(kCVPixelFormatType_32BGRA),
                                                    Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                                                    Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)],
         String(kCVPixelBufferOpenGLESCompatibilityKey): true]
    
    public var requiredPixelBufferAttributesForRenderContext: [String : Any] =
        [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA),
         String(kCVPixelBufferOpenGLESCompatibilityKey): true]

    public func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        renderingQueue.sync {
            renderContext = newRenderContext
        }
    }
    
    enum PixelBufferRequestError: Error {
        case newRenderedPixelBufferForRequestFailure
    }
    
    public func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            renderingQueue.async {
                if self.shouldCancelAllRequests {
                    request.finishCancelledRequest()
                } else {
                    guard let resultPixels = self.newRenderedPixelBufferForRequest(request) else {
                        request.finish(with: PixelBufferRequestError.newRenderedPixelBufferForRequestFailure)
                        return
                    }
                    
                    request.finish(withComposedVideoFrame: resultPixels)
                }
            }
        }
    }
    
    public func cancelAllPendingVideoCompositionRequests() {
        renderingQueue.sync {
            shouldCancelAllRequests = true
        }
        renderingQueue.async {
            self.shouldCancelAllRequests = false
        }
    }
    
    // MARK: - Private
    func newRenderedPixelBufferForRequest(_ request: AVAsynchronousVideoCompositionRequest) -> CVPixelBuffer? {
        guard let newPixelBuffer = renderContext?.newPixelBuffer() else {
            return nil
        }
        
        layerCompositor.renderPixelBuffer(newPixelBuffer, for: request)
        
        return newPixelBuffer
    }
}
