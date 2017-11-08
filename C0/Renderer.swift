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

import Foundation
import AVFoundation

final class SceneImageRendedrer {
    private let drawLayer = DrawLayer()
    let cut: Cut, screenTransform: CGAffineTransform
    let scene: Scene, renderSize: CGSize
    let fileType: String
    init(scene: Scene, renderSize: CGSize, cut: Cut, fileType: String = kUTTypePNG as String) {
        self.scene = scene
        self.renderSize = renderSize
        self.cut = cut
        self.fileType = fileType
        
        let scale = renderSize.width/scene.frame.size.width
        self.screenTransform = Transform(
            translation: CGPoint(x: renderSize.width/2, y: renderSize.height/2),
            scale: CGPoint(x: scale, y: scale), rotation: 0, wiggle: Wiggle()
            ).affineTransform
        
        drawLayer.contentsScale = renderSize.width/scene.frame.size.width
        drawLayer.bounds = scene.frame
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(self.screenTransform)
            self.cut.rootNode.draw(
                scene: scene, viewType: .preview,
                scale: scene.scale, rotation: scene.viewTransform.rotation,
                in: ctx
            )
        }
    }
    
    var image: CGImage? {
        guard
            let colorSpace = CGColorSpace.with(scene.colorSpace),
            let ctx = CGContext.bitmap(with: renderSize, colorSpace: colorSpace) else {
                return nil
        }
        CATransaction.disableAnimation {
            drawLayer.render(in: ctx)
        }
        return ctx.makeImage()
    }
    func writeImage(to url: URL) throws {
        guard let image = image else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        guard let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, fileType as CFString, 1, nil) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        CGImageDestinationAddImage(imageDestination, image, nil)
        if !CGImageDestinationFinalize(imageDestination) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
    }
}

final class SceneMovieRenderer {
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
    
    let scene: Scene, renderSize: CGSize, fileType: String, codec: String
    init(scene: Scene, renderSize: CGSize, fileType: String = AVFileTypeMPEG4, codec: String = AVVideoCodecH264) {
        self.scene = scene
        self.renderSize = renderSize
        self.fileType = fileType
        self.codec = codec
        
        drawLayer.contentsScale = renderSize.width/scene.frame.size.width
        drawLayer.bounds = scene.frame
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(self.screenTransform)
            self.drawCut?.rootNode.draw(
                scene: scene, viewType: .preview,
                scale: scene.scale, rotation: scene.viewTransform.rotation,
                in: ctx
            )
        }
    }
    
    let drawLayer = DrawLayer()
    var drawCut: Cut?
    var screenTransform = CGAffineTransform.identity
    
    func writeMovie(to url: URL, progressHandler: (CGFloat, UnsafeMutablePointer<Bool>) -> Void) throws {
        guard let colorSpace = CGColorSpace.with(scene.colorSpace), let colorSpaceProfile = colorSpace.iccData else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        
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
        
        let allFrameCount = (scene.timeLength.p*scene.frameRate)/scene.timeLength.q
        let scale = renderSize.width/scene.frame.size.width
        var append = false, stop = false
        for i in 0 ..< allFrameCount {
            autoreleasepool {
                let cutTime = scene.cutTime(withFrameRateTime: i.cf)
                let cut = cutTime.cut, time = cutTime.time
                while !writerInput.isReadyForMoreMediaData {
                    progressHandler(i.cf/(allFrameCount - 1).cf, &stop)
                    if stop {
                        append = false
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                guard let bufferPool = adaptor.pixelBufferPool else {
                    append = false
                    return
                }
                var pixelBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, bufferPool, &pixelBuffer)
                guard let pb = pixelBuffer else {
                    append = false
                    return
                }
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
                    screenTransform = Transform(
                        translation: CGPoint(x: renderSize.width/2, y: renderSize.height/2),
                        scale: CGPoint(x: scale, y: scale), rotation: 0, wiggle: Wiggle()
                    ).affineTransform
                    cut.time = time
                    CATransaction.disableAnimation {
                        drawLayer.setNeedsDisplay()
                        drawLayer.render(in: ctx)
                    }
                }
                CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                append = adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i), timescale: Int32(scene.frameRate)))
            }
            if !append {
                break
            }
            progressHandler(i.cf/(allFrameCount - 1).cf, &stop)
            if stop {
                break
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
            writer.endSession(atSourceTime: CMTime(value: Int64(allFrameCount), timescale: Int32(scene.frameRate)))
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
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: RenderderEditorDelegate?
    weak var sceneEditor: SceneEditor!
    
    var pulldownButton = PulldownButton(isSelectable: false, name: Localization(english: "Renderer", japanese: "レンダラー"))
    var renderersResponder = GroupResponder(layer: CALayer.interfaceLayer())
    var pulldownWidth = 100.0.cf
    
    var renderQueue = OperationQueue()
    
    let layer = CALayer.interfaceLayer()
    init() {
        layer.backgroundColor = Color.background2.cgColor
        pulldownButton.frame = CGRect(x: 0, y: 0, width: pulldownWidth, height: Layout.basicHeight)
        children = [pulldownButton, renderersResponder]
        update(withChildren: children, oldChildren: [])
        pulldownButton.delegate = self
        pulldownButton.willOpenMenuHandler = { [unowned self] in
            let size = self.sceneEditor.scene.frame.size
            let size2String = "\(Int(size.width*2)) x \(Int(size.height*2))", size3String = "\(Int(size.width*3)) x \(Int(size.height*3))"
            $0.menu.names = [
                Localization(english: "Export Movie (\(size2String))", japanese: "動画として書き出す (\(size2String))"),
                Localization(english: "Export Movie (\(size2String), Selection Cut Only)", japanese: "動画として書き出す (\(size2String), 選択カットのみ)"),
                Localization(english: "Export Image (\(size2String))", japanese: "画像として書き出す (\(size2String))"),
                Localization(english: "Export Movie (\(size3String))", japanese: "動画として書き出す (\(size3String))"),
                Localization(english: "Export Movie (\(size3String), Selection Cut Only)", japanese: "動画として書き出す (\(size3String), 選択カットのみ)"),
                Localization(english: "Export Image (\(size3String))", japanese: "画像として書き出す (\(size3String))")
            ]
        }
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
                width: newValue.width - pulldownWidth, height: newValue.height
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
        message: String?, name: String? = nil, size: CGSize,
        fileType: String = AVFileTypeMPEG4, codec: String = AVVideoCodecH264, isSelectionCutOnly: Bool
    ) {
        guard
            let utType = SceneMovieRenderer.UTTypeWithAVFileType(fileType),
            let exportURL = delegate?.exportURL(self, message: message, name: nil, fileTypes: [utType]) else {
            return
        }
        let renderer = SceneMovieRenderer(scene: sceneEditor.scene.deepCopy, renderSize: size, fileType: fileType, codec: codec)
        
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
        let renderer = SceneImageRendedrer(scene: sceneEditor.scene, renderSize: size, cut: sceneEditor.scene.editCutItem.cut)
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
            let size = sceneEditor.scene.frame.size
            switch index {
            case 0:
                exportMovie(message: name.currentString, size: size*2, isSelectionCutOnly: false)
            case 1:
                exportMovie(message: name.currentString, size: size*2, isSelectionCutOnly: true)
            case 2:
                exportImage(message: name.currentString, size: size*2)
            case 3:
                exportMovie(message: name.currentString, size: size*3, isSelectionCutOnly: false)
            case 4:
                exportMovie(message: name.currentString, size: size*3, isSelectionCutOnly: true)
            case 5:
                exportImage(message: name.currentString, size: size*3)
            default: break
            }
        }
    }
}
