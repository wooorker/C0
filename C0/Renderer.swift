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
    let scene: Scene, renderSize: CGSize, cut: Cut
    let fileType: String
    init(scene: Scene, renderSize: CGSize, cut: Cut, fileType: String = kUTTypePNG as String) {
        self.scene = scene
        self.renderSize = renderSize
        self.cut = cut
        self.fileType = fileType
        
        let scale = renderSize.width / scene.frame.size.width
        scene.viewTransform = Transform(translation: CGPoint(x: renderSize.width / 2,
                                                             y: renderSize.height / 2),
                                        scale: CGPoint(x: scale, y: scale),
                                        rotation: 0)
        drawLayer.bounds.size = renderSize
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(scene.viewTransform.affineTransform)
            self.scene.editCutItem.cut.draw(scene: self.scene, viewType: .preview, in: ctx)
        }
    }
    
    var image: CGImage? {
        guard
            let colorSpace = CGColorSpace.with(scene.colorSpace),
            let ctx = CGContext.bitmap(with: renderSize, colorSpace: colorSpace) else {
                return nil
        }
        drawLayer.render(in: ctx)
        return ctx.makeImage()
    }
    func writeImage(to url: URL) throws {
        guard let image = image else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        guard let imageDestination = CGImageDestinationCreateWithURL(url as CFURL,
                                                                     fileType as CFString,
                                                                     1, nil) else {
                                                                        
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        CGImageDestinationAddImage(imageDestination, image, nil)
        if !CGImageDestinationFinalize(imageDestination) {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
    }
}

final class SceneMovieRenderer {
    static func UTTypeWithAVFileType(_ fileType: AVFileType) -> String? {
        switch fileType {
        case .mp4:
            return String(kUTTypeMPEG4)
        case .mov:
            return String(kUTTypeQuickTimeMovie)
        default:
            return nil
        }
    }
    
    let scene: Scene, renderSize: CGSize, fileType: AVFileType, codec: String
    init(scene: Scene, renderSize: CGSize,
         fileType: AVFileType = .mp4, codec: String = AVVideoCodecH264) {
        
        self.scene = scene
        self.renderSize = renderSize
        self.fileType = fileType
        self.codec = codec
        
        let scale = renderSize.width / scene.frame.size.width
        self.screenTransform = Transform(translation: CGPoint(x: renderSize.width / 2,
                                                              y: renderSize.height / 2),
                                         scale: CGPoint(x: scale, y: scale),
                                         rotation: 0)
        drawLayer.bounds.size = renderSize
        drawLayer.drawBlock = { [unowned self] ctx in
            ctx.concatenate(scene.viewTransform.affineTransform)
            self.scene.editCutItem.cut.draw(scene: self.scene, viewType: .preview, in: ctx)
        }
    }
    
    let drawLayer = DrawLayer()
    var screenTransform = Transform()
    
    func writeMovie(to url: URL,
                    progressHandler: @escaping (CGFloat, UnsafeMutablePointer<Bool>) -> Void,
                    completionHandler: @escaping (Error?) -> ()) throws {
        guard let colorSpace = CGColorSpace.with(scene.colorSpace),
            let colorSpaceProfile = colorSpace.iccData else {
                throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        
        let writer = try AVAssetWriter(outputURL: url, fileType: fileType)
        
        let width = renderSize.width, height = renderSize.height
        let setting: [String: Any] = [AVVideoCodecKey: codec,
                                      AVVideoWidthKey: width,
                                      AVVideoHeightKey: height]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: setting)
        writerInput.expectsMediaDataInRealTime = true
        writer.add(writerInput)
        
        let attributes: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32ARGB),
            String(kCVPixelBufferWidthKey): width,
            String(kCVPixelBufferHeightKey): height,
            String(kCVPixelBufferCGBitmapContextCompatibilityKey): true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
                                                           sourcePixelBufferAttributes: attributes)
        
        guard writer.startWriting() else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        writer.startSession(atSourceTime: kCMTimeZero)
        
        let allFrameCount = (scene.duration.p * scene.frameRate) / scene.duration.q
        let timeScale = Int32(scene.frameRate)
        
        var append = false, stop = false
        for i in 0 ..< allFrameCount {
            autoreleasepool {
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
                CVBufferSetAttachment(pb, kCVImageBufferICCProfileKey,
                                      colorSpaceProfile, .shouldPropagate)
                CVPixelBufferLockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                if let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb),
                                       width: CVPixelBufferGetWidth(pb),
                                       height: CVPixelBufferGetHeight(pb),
                                       bitsPerComponent: 8,
                                       bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) {
                    
                    let cutTime = scene.cutTime(withFrameTime: i)
                    scene.editCutItemIndex = cutTime.cutItemIndex
                    cutTime.cut.time = cutTime.time
                    drawLayer.render(in: ctx)
                }
                CVPixelBufferUnlockBaseAddress(pb, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                append = adaptor.append(pb, withPresentationTime: CMTime(value: Int64(i),
                                                                         timescale: timeScale))
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
                throw NSError(domain: AVFoundationErrorDomain,
                              code: AVError.Code.exportFailed.rawValue)
            }
        } else {
            writer.endSession(atSourceTime: CMTime(value: Int64(allFrameCount),
                                                   timescale: timeScale))
            writer.finishWriting {
                if let audioURL = self.scene.sound.url {
                    do {
                        try self.wrireAudio(to: url, self.fileType, audioURL: audioURL) { error in
                            completionHandler(error)
                        }
                    } catch {
                        if fileManager.fileExists(atPath: url.path) {
                            try? fileManager.removeItem(at: url)
                        }
                    }
                } else {
                    completionHandler(nil)
                }
            }
        }
    }
    func wrireAudio(to videoURL: URL, _ fileType: AVFileType, audioURL: URL,
                    completionHandler: @escaping (Error?) -> ()) throws {
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(videoURL.lastPathComponent)
        let audioAsset = AVURLAsset(url: audioURL)
        let videoAsset = AVURLAsset(url: videoURL)
        
        let composition = AVMutableComposition()
        guard let videoAssetTrack = videoAsset.tracks(withMediaType: .video).first else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionVideoTrack?.insertTimeRange(CMTimeRange(start: kCMTimeZero,
                                                               duration: videoAsset.duration),
                                                   of: videoAssetTrack,
                                                   at: kCMTimeZero)
        guard let audioAssetTrack = audioAsset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: kCMTimeZero,
                                                               duration: videoAsset.duration),
                                                   of: audioAssetTrack,
                                                   at: kCMTimeZero)
        
        guard let assetExportSession = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality) else
        {
            throw NSError(domain: AVFoundationErrorDomain, code: AVError.Code.exportFailed.rawValue)
        }
        assetExportSession.outputFileType = fileType
        assetExportSession.outputURL = tempURL
        assetExportSession.exportAsynchronously { [unowned assetExportSession] in
            let fileManager = FileManager.default
            do {
                try _ = fileManager.replaceItemAt(videoURL, withItemAt: tempURL)
                if fileManager.fileExists(atPath: tempURL.path) {
                    try fileManager.removeItem(at: tempURL)
                }
                completionHandler(assetExportSession.error)
            } catch {
                completionHandler(error)
            }
        }
    }
}

final class RendererManager {
    weak var progressesEdgeLayer: Layer?
    lazy var scene = Scene()
    var rendingContentScale = 1.0.cf
    let popupBox: PopupBox
    
    var renderQueue = OperationQueue()
    
    init() {
        popupBox = PopupBox(frame: CGRect(x: 0, y: 0, width: 100.0, height: Layout.basicHeight),
                            text: Localization(english: "Export", japanese: "書き出し"))
        popupBox.isSubIndicatedHandler = { [unowned self] isSubIndicated in
            if isSubIndicated {
                self.updatePopupBox(withRendingContentScale: self.rendingContentScale)
            } else {
                self.popupBox.panel.replace(children: [])
            }
        }
    }
    deinit {
        renderQueue.cancelAllOperations()
    }

    func updatePopupBox(withRendingContentScale rendingContentScale: CGFloat) {
        let size = self.scene.frame.size
        let size2 = size * rendingContentScale
        let size720p = CGSize(width: floor((size.width * 720) / size.height), height: 720)
        let size1080p = CGSize(width: floor((size.width * 1080) / size.height), height: 1080)
        let size2160p = CGSize(width: floor((size.width * 2160) / size.height), height: 2160)
        
        let size2String = "w: \(Int(size2.width)) px, h: \(Int(size2.height)) px"
        let size720pString = "w: \(Int(size720p.width)) px, h: 720 px"
        let size1080pString = "w: \(Int(size1080p.width)) px, h: 1080 px"
        let size2160pString = "w: \(Int(size2160p.width)) px, h: 2160 px"
        
        let cutIndexString = Localization(
            english: "No.\(self.scene.editCutItemIndex) Only",
            japanese: "No.\(self.scene.editCutItemIndex)のみ"
            ).currentString
        
        self.popupBox.panel.replace(children: [
            Button(
                name: Localization(
                    english: "Export Movie(\(size2String))",
                    japanese: "動画として書き出す(\(size2String))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size2, isSelectionCutOnly: false)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Movie(\(size720pString))",
                    japanese: "動画として書き出す(\(size720pString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size720p, isSelectionCutOnly: false)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Movie(\(size1080pString))",
                    japanese: "動画として書き出す(\(size1080pString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size1080p, isSelectionCutOnly: false)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Movie(\(size2160pString))",
                    japanese: "動画として書き出す(\(size2160pString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size2160p, isSelectionCutOnly: false)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Movie(\(size2String), \(cutIndexString))",
                    japanese: "動画として書き出す(\(size2String), \(cutIndexString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size2, isSelectionCutOnly: true)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Movie(\(size720pString), \(cutIndexString))",
                    japanese: "動画として書き出す(\(size720pString), \(cutIndexString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size720p, isSelectionCutOnly: true)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Movie(\(size1080pString), \(cutIndexString))",
                    japanese: "動画として書き出す(\(size1080pString), \(cutIndexString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size1080p, isSelectionCutOnly: true)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Movie(\(size2160pString), \(cutIndexString))",
                    japanese: "動画として書き出す(\(size2160pString), \(cutIndexString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportMovie(message: $0.label.string,
                                     size: size2160p, isSelectionCutOnly: true)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Image(\(size2String))",
                    japanese: "画像として書き出す(\(size2String))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportImage(message: $0.label.string, size: size2)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Image(\(size720pString))",
                    japanese: "画像として書き出す(\(size720pString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportImage(message: $0.label.string, size: size720p)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Image(\(size1080pString))",
                    japanese: "画像として書き出す(\(size1080pString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportImage(message: $0.label.string, size: size1080p)
                    return true
                }
            ),
            Button(
                name: Localization(
                    english: "Export Image(\(size2160pString))",
                    japanese: "画像として書き出す(\(size2160pString))"
                ),
                isLeftAlignment: true,
                runHandler: { [unowned self] in
                    self.exportImage(message: $0.label.string, size: size2160p)
                    return true
                }
            )
        ])
        
        var minSize = CGSize()
        Layout.topAlignment(self.popupBox.panel.children, minSize: &minSize)
        self.popupBox.panel.frame.size = CGSize(
            width: minSize.width + Layout.basicPadding * 2,
            height: minSize.height + Layout.basicPadding * 2
        )
    }

    var bars = [Progress]()
    func beginProgress(_ progressBar: Progress) {
        bars.append(progressBar)
        progressesEdgeLayer?.parent?.append(child: progressBar)
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
        guard let view = progressesEdgeLayer else {
            return
        }
        _ = bars.reduce(CGPoint(x: view.frame.origin.x, y: view.frame.maxY)) {
            $1.frame.origin = $0
            return CGPoint(x: $0.x + progressWidth, y: $0.y)
        }
    }
    
    func exportMovie(message: String?, name: String? = nil, size: CGSize,
                     fileType: AVFileType = .mp4, codec: String = AVVideoCodecH264,
                     isSelectionCutOnly: Bool) {
        
        guard let utType = SceneMovieRenderer.UTTypeWithAVFileType(fileType) else {
            return
        }
        URL.file(message: message, name: nil, fileTypes: [utType]) { [unowned self] exportURL in
            let renderer = SceneMovieRenderer(
                scene: self.scene.copied,
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
            progressBar.deleteHandler = { [unowned self] in
                self.endProgress($0)
                return true
            }
            self.beginProgress(progressBar)
            
            operation.addExecutionBlock() { [unowned operation] in
                do {
                    try renderer.writeMovie(to: exportURL.url, progressHandler:
                    { (totalProgress, stop) in
                        if operation.isCancelled {
                            stop.pointee = true
                        } else {
                            OperationQueue.main.addOperation() {
                                progressBar.value = totalProgress
                            }
                        }
                    }, completionHandler: { (error) in
                        do {
                            if let error = error {
                                throw error
                            }
                            OperationQueue.main.addOperation() {
                                progressBar.value = 1
                            }
                            try FileManager.default.setAttributes(
                                [.extensionHidden: exportURL.isExtensionHidden],
                                ofItemAtPath: exportURL.url.path
                            )
                            OperationQueue.main.addOperation() {
                                self.endProgress(progressBar)
                            }
                        } catch {
                            OperationQueue.main.addOperation() {
                                progressBar.state = Localization(english: "Error", japanese: "エラー")
                                progressBar.label.textFrame.color = .warning
                            }
                        }
                    })
                } catch {
                    OperationQueue.main.addOperation() {
                        progressBar.state = Localization(english: "Error", japanese: "エラー")
                        progressBar.label.textFrame.color = .warning
                    }
                }
            }
            self.renderQueue.addOperation(operation)
        }
    }
    
    func exportImage(message: String?, size: CGSize) {
        URL.file(message: message, name: nil, fileTypes: [kUTTypePNG as String]) {
            [unowned self] exportURL in
            
            let renderer = SceneImageRendedrer(scene: self.scene.copied,
                                               renderSize: size,
                                               cut: self.scene.editCutItem.cut)
            do {
                try renderer.writeImage(to: exportURL.url)
                try FileManager.default.setAttributes([.extensionHidden: exportURL.isExtensionHidden],
                                                      ofItemAtPath: exportURL.url.path)
            } catch {
                let progressBar = Progress()
                progressBar.name = exportURL.name
                progressBar.state = Localization(english: "Error", japanese: "エラー")
                progressBar.label.textFrame.color = .warning
                progressBar.deleteHandler = { [unowned self] in
                    self.endProgress($0)
                    return true
                }
                self.beginProgress(progressBar)
            }
        }
    }
}
