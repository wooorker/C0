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

//# Issue
//書き出し時間表示の精度を改善

import Foundation
import AVFoundation

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
            self.drawCut?.rootNode.draw(scene: scene, with: self.drawInfo, in: ctx)
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
    
    var image: CGImage? {
        guard
            let colorSpace = CGColorSpace(name: colorSpaceName),
            let ctx = CGContext.bitmap(with: renderSize, colorSpace: colorSpace),
            let cut = cuts.first else {
            return nil
        }
        scene.viewTransform.scale = renderSize.width/scene.cameraFrame.size.width//, zoomScale = cut.camera.transform.zoomScale.width
        drawCut = cut
//        drawInfo = DrawInfo(scale: zoomScale, cameraScale: zoomScale, rotation: cut.camera.transform.rotation)
//        ctx.scaleBy(x: scale, y: scale)
        CATransaction.disableAnimation {
            drawLayer.render(in: ctx)
        }
        return ctx.makeImage()
    }
    func writeImage(to url: URL) throws {
        guard let image = image else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        guard let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        CGImageDestinationAddImage(imageDestination, image, nil)
        if !CGImageDestinationFinalize(imageDestination) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
    }
    
    func writeMovie(to url: URL, progressHandler: (CGFloat, UnsafeMutablePointer<Bool>) -> Void) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
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
        
        guard writer.startWriting() else {
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
                                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                                ) {
                                    ctx.scaleBy(x: scale, y: scale)
                                    CATransaction.disableAnimation {
                                        cut.time = i
//                                        let zoomScale = cut.camera.transform.zoomScale.width
//                                        drawInfo = DrawInfo(scale: zoomScale, cameraScale: zoomScale, rotation: cut.camera.transform.rotation)
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
                try? fileManager.removeItem(at: url)
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

protocol RenderderEditorDelegate: class {
    func exportURL(
        _ rendererEditor: RendererEditor, message: String?, name: String?, fileTypes: [String]
    ) -> (url: URL, name: String, isExtensionHidden: Bool)?
}
final class RendererEditor: LayerRespondable, PulldownButtonDelegate, ProgressBarDelegate {
    static let name = Localization(english: "Renderer Editor", japanese: "レンダラーエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: RenderderEditorDelegate?
    weak var sceneEditor: SceneEditor!
    
    var pulldownButton = PulldownButton(
        isSelectable: false, name: Localization(english: "Renderer", japanese: "レンダラー"),
        names: [
            Localization(english: "Export 720p Movie", japanese: "720p動画として書き出す"),
            Localization(english: "Export 1080p Movie", japanese: "1080p動画として書き出す"),
            Localization(english: "Export 720p Movie with Selection Cut", japanese: "選択カットを720p動画として書き出す"),
            Localization(english: "Export 1080p Movie with Selection Cut", japanese: "選択カットを1080p動画として書き出す"),
            Localization(english: "Export 720p Image", japanese: "720p画像として書き出す"),
            Localization(english: "Export 1080p Image", japanese: "1080p画像として書き出す")
        ]
    )
    var renderersResponder = GroupResponder(layer: CALayer.interfaceLayer())
    var pulldownWidth = 100.0.cf
    
    var renderQueue = OperationQueue()
    
    let layer = CALayer.interfaceLayer()
    init() {
        layer.backgroundColor = Color.background2.cgColor
        pulldownButton.frame = CGRect(x: 0, y: 0, width: pulldownWidth, height: SceneEditor.Layout.buttonHeight)
        children = [pulldownButton, renderersResponder]
        update(withChildren: children)
        pulldownButton.delegate = self
    }
    deinit {
        renderQueue.cancelAllOperations()
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            renderersResponder.frame = CGRect(
                x: pulldownWidth, y: 0,
                width: newValue.width - pulldownWidth, height: SceneEditor.Layout.buttonHeight
            )
        }
    }
    
    var bars = [(nameLabel: Label, progressBar: ProgressBar)]()
    func beginProgress(_ progressBar: ProgressBar) {
        let nameLabel = Label(string: progressBar.name + ":", backgroundColor: Color.background4, height: bounds.height)
        nameLabel.frame.size = CGSize(width: nameLabel.textLine.stringBounds.width + 10, height: bounds.height)
        bars.append((nameLabel, progressBar))
        renderersResponder.children = children + [nameLabel, progressBar]
        progressBar.begin()
        updateProgressBarsPosition()
    }
    func endProgress(_ progressBar: ProgressBar) {
        progressBar.end()
        for (i, pb) in bars.enumerated() {
            if pb.progressBar === progressBar {
                pb.progressBar.removeFromParent()
                pb.nameLabel.removeFromParent()
                bars.remove(at: i)
                break
            }
        }
        updateProgressBarsPosition()
    }
    private let padding = 2.0.cf, progressWidth = 120.0.cf, barPadding = 3.0.cf
    func updateProgressBarsPosition() {
        var x = pulldownButton.frame.width
        for bs in bars {
            bs.nameLabel.frame = CGRect(x: x, y: 0, width: bs.nameLabel.frame.width, height: bounds.height)
            x += bs.nameLabel.frame.width
            bs.progressBar.frame = CGRect(x: x, y: 0, width: progressWidth, height: bounds.height).inset(by: barPadding)
            x += progressWidth + padding
        }
    }
    
    func delete(_ progressBar: ProgressBar) {
        if progressBar.operation?.isFinished ?? true {
            progressBar.removeFromParent()
        }
    }
    
    func exportMovie(
        message: String?, name: String? = nil, size: CGSize, frameRate: CGFloat,
        fileType: String = AVFileTypeMPEG4, codec: String = AVVideoCodecH264, isSelectionCutOnly: Bool
    ) {
        guard
            let utType = Renderer.UTTypeWithAVFileType(fileType),
            let exportURL = delegate?.exportURL(self, message: message, name: nil, fileTypes: [utType]) else {
            return
        }
        let copyCuts = isSelectionCutOnly ? [sceneEditor.scene.editCutItem.cut.deepCopy] : sceneEditor.scene.cutItems.map { $0.cut.deepCopy }
        let renderer = Renderer(scene: sceneEditor.scene, cuts: copyCuts, renderSize: size)
        renderer.fileType = fileType
        renderer.codec = codec
        
        let progressBar = ProgressBar(), operation = BlockOperation()
        progressBar.operation = operation
        progressBar.name = exportURL.name
        progressBar.delegate = self
        self.beginProgress(progressBar)
        
        operation.addExecutionBlock() { [unowned operation] in
            do {
                try renderer.writeMovie(to: exportURL.url) { (totalProgress: CGFloat, stop:  UnsafeMutablePointer<Bool>) in
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
                        try FileManager.default.setAttributes(
                            [FileAttributeKey.extensionHidden: exportURL.isExtensionHidden], ofItemAtPath: exportURL.url.path
                        )
                    } catch {
                        progressBar.state = Localization(english: "Error", japanese: "エラー")
                    }
                    self.endProgress(progressBar)
                }
            } catch {
                OperationQueue.main.addOperation() {
                    progressBar.state = Localization(english: "Error", japanese: "エラー")
                }
            }
        }
        self.renderQueue.addOperation(operation)
    }
    
    func exportImage(message: String?, size: CGSize) {
        guard let exportURL = delegate?.exportURL(self, message: message, name: nil, fileTypes: [String(kUTTypePNG)]) else {
            return
        }
        let renderer = Renderer(scene: sceneEditor.scene, cuts: [sceneEditor.scene.editCutItem.cut], renderSize: size)
        do {
            try renderer.writeImage(to: exportURL.url)
            try FileManager.default.setAttributes(
                [FileAttributeKey.extensionHidden: exportURL.isExtensionHidden], ofItemAtPath: exportURL.url.path
            )
        } catch {
            let progressBar = ProgressBar()
            progressBar.name = exportURL.name
            progressBar.state = Localization(english: "Error", japanese: "エラー")
            progressBar.delegate = self
            self.beginProgress(progressBar)
        }
    }
    
    func changeValue(_ pulldownButton: PulldownButton, index: Int, oldIndex: Int, type: Action.SendType) {
        if type == .end {
            let name = pulldownButton.menu.names[index]
            switch index {
            case 0:
                exportMovie(message: name.currentString, size: CGSize(width: 1280, height: 720), frameRate: 24, isSelectionCutOnly: false)
            case 1:
                exportMovie(message: name.currentString, size: CGSize(width: 1920, height: 1080), frameRate: 24, isSelectionCutOnly: false)
            case 2:
                exportMovie(message: name.currentString, size: CGSize(width: 1280, height: 720), frameRate: 24, isSelectionCutOnly: true)
            case 3:
                exportMovie(message: name.currentString, size: CGSize(width: 1920, height: 1080), frameRate: 24, isSelectionCutOnly: true)
            case 4:
                exportImage(message: name.currentString, size: CGSize(width: 1280, height: 720))
            case 5:
                exportImage(message: name.currentString, size: CGSize(width: 1920, height: 1080))
            default: break
            }
        }
    }
}
