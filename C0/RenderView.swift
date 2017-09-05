/*
 Copyright 2017 S
 
 This file is part of C0.
 
 C0 is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 C0 is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with C0.  If not, see <http://www.gnu.org/licenses/>.
 */

import Cocoa
import AVFoundation

final class RenderView: View {
    weak var sceneView: SceneView!
    
    var renderQueue = OperationQueue()
    
    override init(layer: CALayer = CALayer.interfaceLayer()) {
        super.init(layer: layer)
        layer.backgroundColor = Defaults.subBackgroundColor2.cgColor
        layer.isHidden = true
    }
    
    var bars = [(nameView: StringView, progressBar: ProgressBar)]() {
        didSet {
            if bars.isEmpty != oldValue.isEmpty {
                if bars.isEmpty {
                    layer.isHidden = true
                } else {
                    CATransaction.disableAnimation {
                        layer.isHidden = false
                    }
                }
            }
        }
    }
    func beginProgress(_ progressBar: ProgressBar) {
        let nameView = StringView(string: progressBar.name + ":", backgroundColor: Defaults.subBackgroundColor3.cgColor, height: bounds.height)
        nameView.frame.size = CGSize(width: nameView.textLine.stringBounds.width + 10, height: bounds.height)
        bars.append((nameView, progressBar))
        addChild(nameView)
        addChild(progressBar)
        progressBar.begin()
        updateProgressBarsPosition()
    }
    func endProgress(_ progressBar: ProgressBar) {
        progressBar.end()
        for (i, pb) in bars.enumerated() {
            if pb.progressBar === progressBar {
                pb.progressBar.removeFromParent()
                pb.nameView.removeFromParent()
                bars.remove(at: i)
                break
            }
        }
        updateProgressBarsPosition()
    }
    private let padding = 2.0.cf, progressWidth = 120.0.cf, barPadding = 3.0.cf
    func updateProgressBarsPosition() {
        var x = 0.0.cf
        for bs in bars {
            bs.nameView.frame = CGRect(x: x, y: 0, width: bs.nameView.frame.width, height: bounds.height)
            x += bs.nameView.frame.width
            bs.progressBar.frame = CGRect(x: x, y: 0, width: progressWidth, height: bounds.height).inset(by: barPadding)
            x += progressWidth + padding
        }
    }
    
    func exportMovie(message m: String?, name: String? = nil, size: CGSize, fps: CGFloat, fileType: String = AVFileTypeMPEG4, codec: String = AVVideoCodecH264, isSelectionCutOnly: Bool) {
        if let window = sceneView.screen?.window, let utType = Renderer.UTTypeWithAVFileType(fileType) {
            let savePanel = NSSavePanel()
            if let name = name {
                savePanel.nameFieldStringValue = name
            }
            savePanel.message = m
            savePanel.canSelectHiddenExtension = true
            savePanel.allowedFileTypes = [utType]
            savePanel.beginSheetModal(for: window) { [unowned savePanel] result in
                if result == NSFileHandlingPanelOKButton, let url = savePanel.url {
                    let copyCuts = isSelectionCutOnly ? [self.sceneView.cutView.cut.deepCopy] : self.sceneView.sceneEntity.cuts.map { $0.deepCopy }
                    let renderer = Renderer(scene: self.sceneView.scene, cuts: copyCuts, renderSize: size)
                    renderer.fileType = fileType
                    renderer.codec = codec
                    
                    let progressBar = ProgressBar(), operation = BlockOperation(), extensionHidden = savePanel.isExtensionHidden
                    progressBar.operation = operation
                    progressBar.name = savePanel.nameFieldStringValue
                    self.beginProgress(progressBar)
                    
                    operation.addExecutionBlock() { [unowned operation] in
                        do {
                            try renderer.writeMovie(to: url) { (totalProgress: CGFloat, stop:  UnsafeMutablePointer<Bool>) in
                                if operation.isCancelled {
                                    stop.pointee = true
                                } else {
                                    OperationQueue.main.addOperation() {
                                        progressBar.value = totalProgress
                                    }
                                }
                            }
                            OperationQueue.main.addOperation() {
                                do {
                                    try FileManager.default.setAttributes([FileAttributeKey.extensionHidden: extensionHidden], ofItemAtPath: url.path)
                                } catch {
                                    OperationQueue.main.addOperation() {
                                        self.sceneView.screen?.errorNotification(error)
                                    }
                                }
                                self.endProgress(progressBar)
                            }
                        } catch {
                            OperationQueue.main.addOperation() {
                                self.sceneView.screen?.errorNotification(error)
                            }
                        }
                    }
                    self.renderQueue.addOperation(operation)
                }
            }
        }
    }
    func exportImage(message: String?, size: CGSize) {
        if let sceneView = sceneView, let window = sceneView.screen?.window {
            let savePanel = NSSavePanel()
            savePanel.message = message
            savePanel.canSelectHiddenExtension = true
            savePanel.allowedFileTypes = [String(kUTTypePNG)]
            savePanel.beginSheetModal(for: window) { [unowned savePanel] result in
                if result == NSFileHandlingPanelOKButton, let url = savePanel.url {
                    let renderer = Renderer(scene: sceneView.scene, cuts: [sceneView.timeline.selectionCutEntity.cut], renderSize: size)
                    do {
                        try renderer.image?.PNGRepresentation?.write(to: url)
                        try FileManager.default.setAttributes([FileAttributeKey.extensionHidden: savePanel.isExtensionHidden], ofItemAtPath: url.path)
                    }
                    catch {
                        sceneView.screen?.errorNotification(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError))
                    }
                }
            }
        }
    }
}

final class Renderer {
    static func UTTypeWithAVFileType(_ fileType: String) -> String? {
        switch fileType {
        case AVFileTypeMPEG4:
            return String(kUTTypeMPEG4)
        case AVFileTypeQuickTimeMovie:
            return String(kUTTypeQuickTimeMovie)
        default:
            return nil
        }
    }
    
    init(scene: Scene, cuts: [Cut], renderSize: CGSize) {
        self.scene = scene
        self.cuts = cuts
        self.renderSize = renderSize
        
        drawLayer.contentsScale = renderSize.width/scene.cameraFrame.size.width
        drawLayer.bounds = scene.cameraFrame
        drawLayer.drawBlock = { [unowned self] ctx in
            self.drawCut?.draw(scene, with: self.drawInfo, in: ctx)
        }
        var frameCount = 0, maxTime = 0
        for cut in cuts {
            frameCount += cut.timeLength
            maxTime += cut.timeLength
        }
        self.frameCount = frameCount
        self.maxTime = maxTime
    }
    
    let drawLayer = DrawLayer()
    var scene = Scene(), drawInfo = DrawInfo(), cuts = [Cut](), renderSize = CGSize()
    var fileType = AVFileTypeMPEG4, codec = AVVideoCodecH264, maxTime = 0, frameCount = 0
    var drawCut: Cut?
    var colorSpaceName = CGColorSpace.sRGB
    
    var image: NSImage? {
        if let colorSpace = CGColorSpace(name: colorSpaceName), let ctx = CGContext(data: nil, width: Int(renderSize.width), height: Int(renderSize.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
            if let cut = cuts.first {
                let scale = renderSize.width/scene.cameraFrame.size.width, zoomScale = cut.camera.transform.zoomScale.width
                drawCut = cut
                drawInfo = DrawInfo(scale: zoomScale, cameraScale: zoomScale, rotation: cut.camera.transform.rotation)
                ctx.scaleBy(x: scale, y: scale)
                CATransaction.disableAnimation {
                    drawLayer.render(in: ctx)
                }
                if let cgImage = ctx.makeImage() {
                    return NSImage(cgImage: cgImage, size: NSSize())
                }
            }
        }
        return nil
    }
    
    func writeMovie(to url: URL, progressHandler: (CGFloat, UnsafeMutablePointer<Bool>) -> Void) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        let writer = try AVAssetWriter(outputURL: url, fileType:fileType)
        let width = renderSize.width, height = renderSize.height
        let setting: [String : Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        let writerInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: setting)
        writerInput.expectsMediaDataInRealTime = true
        writer.add(writerInput)
        
        let attributes: [String : Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32ARGB),
            String(kCVPixelBufferWidthKey): width,
            String(kCVPixelBufferHeightKey): height,
            String(kCVPixelBufferCGBitmapContextCompatibilityKey): true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: attributes)
        
        if !writer.startWriting() {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        writer.startSession(atSourceTime: kCMTimeZero)
        
        var append = false, stop = false, timeLocation = 0
        let scale = renderSize.width / scene.cameraFrame.size.width
        if let colorSpace = CGColorSpace(name: colorSpaceName), let colorSpaceProfile = colorSpace.iccData {
            for cut in cuts {
                drawCut = cut
                for i in 0 ..< cut.timeLength {
                    autoreleasepool {
                        while !writerInput.isReadyForMoreMediaData {
                            progressHandler(i.cf/(maxTime - 1).cf, &stop)
                            if stop {
                                return
                            }
                            Thread.sleep(forTimeInterval: 0.1)
                        }
                        if let bufferPool = adaptor.pixelBufferPool {
                            var pixelBuffer: CVPixelBuffer?
                            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, bufferPool, &pixelBuffer)
                            if let pb = pixelBuffer {
                                CVBufferSetAttachment(pb, kCVImageBufferICCProfileKey, colorSpaceProfile, .shouldPropagate)
                                CVPixelBufferLockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                                if let ctx = CGContext(
                                    data: CVPixelBufferGetBaseAddress(pb),
                                    width: CVPixelBufferGetWidth(pb),
                                    height: CVPixelBufferGetHeight(pb),
                                    bitsPerComponent: 8,
                                    bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
                                    
                                    ctx.scaleBy(x: scale, y: scale)
                                    CATransaction.disableAnimation {
                                        cut.time = i
                                        let zoomScale = cut.camera.transform.zoomScale.width
                                        drawInfo = DrawInfo(scale: zoomScale, cameraScale: zoomScale, rotation: cut.camera.transform.rotation)
                                        drawLayer.setNeedsDisplay()
                                        drawLayer.render(in: ctx)
                                    }
                                }
                                CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                                append = adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i + timeLocation), timescale: Int32(scene.frameRate)))
                                if !append {
                                    return
                                }
                                progressHandler((i + timeLocation).cf/(maxTime - 1).cf, &stop)
                                if stop {
                                    return
                                }
                            }
                        }
                    }
                    if !append || stop {
                        break
                    }
                }
                if !append || stop {
                    break
                }
                timeLocation += cut.timeLength
            }
        }
        
        writerInput.markAsFinished()
        if !append || stop {
            writer.cancelWriting()
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            if !append {
                throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
            }
        } else {
            writer.endSession(atSourceTime: CMTime(value: Int64(maxTime), timescale: Int32(scene.frameRate)))
            writer.finishWriting {}
            progressHandler(1, &stop)
        }
    }
}
