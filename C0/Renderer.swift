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
    let scene: Scene, renderSize: CGSize, cut: Cut, screenTransform: CGAffineTransform
    let fileType: String
    init(scene: Scene, renderSize: CGSize, cut: Cut, fileType: String = kUTTypePNG as String) {
        self.scene = scene
        self.renderSize = renderSize
        self.cut = cut
        self.fileType = fileType
        
        let scale = renderSize.width / scene.frame.size.width
        self.screenTransform = Transform(translation: CGPoint(x: renderSize.width / 2,
                                                              y: renderSize.height / 2),
                                         scale: CGPoint(x: scale, y: scale),
                                         rotation: 0,
                                         wiggle: Wiggle()).affineTransform
        
        drawLayer.contentsScale = renderSize.width / scene.frame.size.width
        drawLayer.bounds = scene.frame
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(self.screenTransform)
            self.cut.rootNode.draw(
                scene: scene, viewType: .preview,
                scale: 1, rotation: 0,
                viewScale: scene.scale, viewRotation: scene.viewTransform.rotation,
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
        
        drawLayer.bounds.size = renderSize
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(self.screenTransform.affineTransform)
            self.scene.editCutItem.cut.rootNode.draw(
                scene: scene, viewType: .preview,
                scale: self.screenTransform.scale.x, rotation: self.screenTransform.rotation,
                viewScale: self.screenTransform.scale.x * scene.scale,
                viewRotation: self.screenTransform.rotation + scene.viewTransform.rotation,
                in: ctx
            )
        }
    }
    
    let drawLayer = DrawLayer()
    var screenTransform = Transform()
    
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
        
        let allFrameCount = (scene.timeLength.p * scene.frameRate) / scene.timeLength.q
        let scale = renderSize.width / scene.frame.size.width
        self.screenTransform = Transform(
            translation: CGPoint(x: renderSize.width / 2, y: renderSize.height / 2),
            scale: CGPoint(x: scale, y: scale), rotation: 0, wiggle: Wiggle()
        )
        
        var append = false, stop = false
        for i in 0 ..< allFrameCount {
            autoreleasepool {
                Thread.sleep(forTimeInterval: 2)
                while !writerInput.isReadyForMoreMediaData {
                    progressHandler(i.cf / (allFrameCount - 1).cf, &stop)
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
                    let cutTime = scene.cutTime(withFrameTime: i)
                    scene.editCutItemIndex = cutTime.cutItemIndex
                    cutTime.cut.time = cutTime.time
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
            progressHandler(i.cf / (allFrameCount - 1).cf, &stop)
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

final class RendererManager: ProgressDelegate {
    weak var sceneEditor: SceneEditor!
    
    let popupBox: PopupBox
    
    var renderQueue = OperationQueue()
    
    init() {
        self.popupBox = PopupBox(
            frame: CGRect(x: 0, y: 0, width: 100.0, height: Layout.basicPadding),
            text: Localization(english: "Export", japanese: "書き出し")
        )
        popupBox.isSubIndicationHandler = { [unowned self] isSubIndication in
            if isSubIndication {
                let size = self.sceneEditor.scene.frame.size
                let size2 = size * self.sceneEditor.canvas.contentsScale
                let size720p = CGSize(width: floor((size.width * 720) / size.height), height: 720)
                let size1080p = CGSize(width: floor((size.width * 1080) / size.height), height: 1080)
                let size2160p = CGSize(width: floor((size.width * 2160) / size.height), height: 2160)
                
                let size2String = "w: \(Int(size2.width)) px, h: \(Int(size2.height)) px"
                let size720pString = "w: \(Int(size720p.width)) px, h: 720 px"
                let size1080pString = "w: \(Int(size1080p.width)) px, h: 1080 px"
                let size2160pString = "w: \(Int(size2160p.width)) px, h: 2160 px"
                
                let cutIndexString = Localization(
                    english: "No.\(self.sceneEditor.scene.editCutItemIndex) Only",
                    japanese: "No.\(self.sceneEditor.scene.editCutItemIndex)のみ"
                ).currentString
                
                self.popupBox.panel.children = [
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size2String))",
                            japanese: "動画として書き出す(\(size2String))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size2, isSelectionCutOnly: false
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size720pString))",
                            japanese: "動画として書き出す(\(size720pString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size720p, isSelectionCutOnly: false
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size1080pString))",
                            japanese: "動画として書き出す(\(size1080pString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size1080p, isSelectionCutOnly: false
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size2160pString))",
                            japanese: "動画として書き出す(\(size2160pString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size2160p, isSelectionCutOnly: false
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size2String), \(cutIndexString))",
                            japanese: "動画として書き出す(\(size2String), \(cutIndexString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size2, isSelectionCutOnly: true
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size720pString), \(cutIndexString))",
                            japanese: "動画として書き出す(\(size720pString), \(cutIndexString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size720p, isSelectionCutOnly: true
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size1080pString), \(cutIndexString))",
                            japanese: "動画として書き出す(\(size1080pString), \(cutIndexString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size1080p, isSelectionCutOnly: true
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Movie(\(size2160pString), \(cutIndexString))",
                            japanese: "動画として書き出す(\(size2160pString), \(cutIndexString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportMovie(
                                message: $0.label.text.string, size: size2160p, isSelectionCutOnly: true
                            )
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Image(\(size2String))",
                            japanese: "画像として書き出す(\(size2String))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportImage(message: $0.label.text.string, size: size2)
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Image(\(size720pString))",
                            japanese: "画像として書き出す(\(size720pString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportImage(message: $0.label.text.string, size: size720p)
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Image(\(size1080pString))",
                            japanese: "画像として書き出す(\(size1080pString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportImage(message: $0.label.text.string, size: size1080p)
                        }
                    ),
                    Button(
                        name: Localization(
                            english: "Export Image(\(size2160pString))",
                            japanese: "画像として書き出す(\(size2160pString))"
                        ),
                        isLeftAlignment: true,
                        clickHandler: { [unowned self] in
                            self.exportImage(message: $0.label.text.string, size: size1080p)
                        }
                    )
                ]
                
                var minSize = CGSize()
                Layout.topAlignment(self.popupBox.panel.children, minSize: &minSize)
                self.popupBox.panel.frame.size = CGSize(
                    width: minSize.width + Layout.basicPadding * 2,
                    height: minSize.height + Layout.basicPadding * 2
                )
            } else {
                self.popupBox.panel.children = []
            }
        }
    }
    deinit {
        renderQueue.cancelAllOperations()
    }
    
    var bars = [Progress]()
    func beginProgress(_ progressBar: Progress) {
        bars.append(progressBar)
        sceneEditor.parent?.children.append(progressBar)
        progressBar.begin()
        updateProgresssPosition()
    }
    func endProgress(_ progressBar: Progress) {
        progressBar.end()
        if let index = bars.index(where: { $0 === progressBar }) {
            bars[index].removeFromParent()
            bars.remove(at: index)
            updateProgresssPosition()
        }
    }
    private let progressWidth = 200.0.cf
    func updateProgresssPosition() {
        var origin = CGPoint(x: sceneEditor.frame.origin.x, y: sceneEditor.frame.maxY)
        for bs in bars {
            bs.frame.origin = origin
            origin.x += progressWidth
        }
    }
    
    func delete(_ progressBar: Progress) {
        endProgress(progressBar)
    }
    
    func exportMovie(
        message: String?, name: String? = nil, size: CGSize,
        fileType: String = AVFileTypeMPEG4, codec: String = AVVideoCodecH264, isSelectionCutOnly: Bool
    ) {
        guard let utType = SceneMovieRenderer.UTTypeWithAVFileType(fileType) else {
            return
        }
        URL.file(message: message,
                 name: nil,
                 fileTypes: [utType]) { [unowned self] exportURL in
            let renderer = SceneMovieRenderer(
                scene: self.sceneEditor.scene.deepCopy,
                renderSize: size, fileType: fileType, codec: codec
            )
            
            let progressBar = Progress(
                frame: CGRect(
                    x: 0, y: 0,
                    width: self.progressWidth, height: Layout.basicHeight
                ),
                name: exportURL.url.deletingPathExtension().lastPathComponent,
                type: exportURL.url.pathExtension.uppercased(),
                state: Localization(english: "Exporting", japanese: "書き出し中")
            )
            let operation = BlockOperation()
            progressBar.operation = operation
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
                            progressBar.label.text.textFrame.color = .red
                        }
                        self.endProgress(progressBar)
                    }
                } catch {
                    OperationQueue.main.addOperation() {
                        progressBar.state = Localization(english: "Error", japanese: "エラー")
                        progressBar.label.text.textFrame.color = .red
                    }
                }
            }
            self.renderQueue.addOperation(operation)
        }
    }
    
    func exportImage(message: String?, size: CGSize) {
        URL.file(message: message,
                 name: nil,
                 fileTypes: [String(kUTTypePNG)]) { [unowned self] exportURL in
            let renderer = SceneImageRendedrer(scene: self.sceneEditor.scene, renderSize: size, cut: self.sceneEditor.scene.editCutItem.cut)
            do {
                try renderer.writeImage(to: exportURL.url)
                try FileManager.default.setAttributes(
                    [FileAttributeKey.extensionHidden: exportURL.isExtensionHidden], ofItemAtPath: exportURL.url.path
                )
            } catch {
                let progressBar = Progress()
                progressBar.name = exportURL.name
                progressBar.state = Localization(english: "Error", japanese: "エラー")
                progressBar.label.text.textFrame.color = .red
                progressBar.delegate = self
                self.beginProgress(progressBar)
            }
        }
    }
}
