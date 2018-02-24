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

struct Font {
    static let `default` = Font(monospacedSize: 11)
    static let bold = Font(boldMonospacedSize: 11)
    static let italic = Font(italicMonospacedSize: 11)
    static let small = Font(monospacedSize: 8)
    static let action = Font(boldMonospacedSize: 9)
    static let hedding0 = Font(boldMonospacedSize: 14)
    static let hedding1 = Font(boldMonospacedSize: 10)
    static let speech = Font(boldMonospacedSize: 25)
    
    let name: String, size: CGFloat
    let ascent: CGFloat, descent: CGFloat, leading: CGFloat, ctFont: CTFont
    init(size: CGFloat) {
        self.init(NSFont.systemFont(ofSize: size))
    }
    init(boldSize size: CGFloat) {
        self.init(NSFont.boldSystemFont(ofSize: size))
    }
    init(monospacedSize size: CGFloat) {
        self.init(NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium))
    }
    init(boldMonospacedSize size: CGFloat) {
        self.init(NSFont.monospacedDigitSystemFont(ofSize: size, weight: .bold))
    }
    init(italicMonospacedSize size: CGFloat) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
        self.init(NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask))
    }
    init(name: String, size: CGFloat) {
        self.init(CTFontCreateWithName(name as CFString, size, nil))
    }
    init(_ ctFont: CTFont) {
        self.name = CTFontCopyFullName(ctFont) as String
        self.size = CTFontGetSize(ctFont)
        self.ascent = CTFontGetAscent(ctFont)
        self.descent = -CTFontGetDescent(ctFont)
        self.leading = -CTFontGetLeading(ctFont)
        self.ctFont = ctFont
    }
    
    func ceilHeight(withPadding padding: CGFloat) -> CGFloat {
        return ceil(ascent - descent) + padding * 2
    }
}

struct Cursor: Equatable {
    static let arrow = Cursor(NSCursor.arrow)
    static let iBeam = Cursor(NSCursor.iBeam)
    static let leftRight = slideCursor(isVertical: false)
    static let upDown = slideCursor(isVertical: true)
    static let pointingHand = Cursor(NSCursor.pointingHand)
    static let stroke = circleCursor(size: 2)
    static func circleCursor(size s: CGFloat, color: Color = .black,
                             outlineColor: Color = .white) -> Cursor {
        let lineWidth = 2.0.cf, subLineWidth = 1.0.cf
        let d = subLineWidth + lineWidth / 2
        let b = CGRect(x: d, y: d, width: d * 2 + s, height: d * 2 + s)
        let image = NSImage(size: CGSize(width: s + d * 2 * 2,  height: s + d * 2 * 2)) { ctx in
            ctx.setLineWidth(lineWidth + subLineWidth * 2)
            ctx.setFillColor(outlineColor.with(alpha: 0.35).cgColor)
            ctx.setStrokeColor(outlineColor.with(alpha: 0.8).cgColor)
            ctx.addEllipse(in: b)
            ctx.drawPath(using: .fillStroke)
            ctx.setLineWidth(lineWidth)
            ctx.setStrokeColor(color.cgColor)
            ctx.strokeEllipse(in: b)
        }
        return Cursor(NSCursor(image: image, hotSpot: NSPoint(x: d * 2 + s / 2, y: -d * 2 - s / 2)))
    }
    static func slideCursor(color: Color = .black, outlineColor: Color = .white,
                            isVertical: Bool) -> Cursor {
        let lineWidth = 1.0.cf, lineHalfWidth = 4.0.cf, halfHeight = 4.0.cf, halfLineHeight = 1.5.cf
        let aw = floor(halfHeight * sqrt(3)), d = lineWidth / 2
        let w = ceil(aw * 2 + lineHalfWidth * 2 + d), h =  ceil(halfHeight * 2 + d)
        let size = isVertical ? CGSize(width: h,  height: w) : CGSize(width: w,  height: h)
        let image = NSImage(size: size) { ctx in
            if isVertical {
                ctx.translateBy(x: h / 2, y: w / 2)
                ctx.rotate(by: .pi / 2)
                ctx.translateBy(x: -w / 2, y: -h / 2)
            }
            ctx.addLines(
                between: [
                    CGPoint(x: d, y: d + halfHeight),
                    CGPoint(x: d + aw, y: d + halfHeight * 2),
                    CGPoint(x: d + aw, y: d + halfHeight + halfLineHeight),
                    CGPoint(x: d + aw + lineHalfWidth * 2, y: d + halfHeight + halfLineHeight),
                    CGPoint(x: d + aw + lineHalfWidth * 2, y: d + halfHeight * 2),
                    CGPoint(x: d + aw * 2 + lineHalfWidth * 2, y: d + halfHeight),
                    CGPoint(x: d + aw + lineHalfWidth * 2, y: d),
                    CGPoint(x: d + aw + lineHalfWidth * 2, y: d + halfHeight - halfLineHeight),
                    CGPoint(x: d + aw, y: d + halfHeight - halfLineHeight),
                    CGPoint(x: d + aw, y: d)
                ]
            )
            ctx.closePath()
            ctx.setLineJoin(.miter)
            ctx.setLineWidth(lineWidth)
            ctx.setFillColor(color.cgColor)
            ctx.setStrokeColor(outlineColor.cgColor)
            ctx.drawPath(using: .fillStroke)
        }
        return Cursor(NSCursor(image: image,
                               hotSpot: isVertical ?
                                CGPoint(x: h / 2, y: -w / 2) : CGPoint(x: w / 2, y: -h / 2)))
    }
    
    let image: CGImage, hotSpot: CGPoint
    fileprivate let nsCursor: NSCursor
    private init(_ nsCursor: NSCursor) {
        self.image = nsCursor.image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        self.hotSpot = nsCursor.hotSpot
        self.nsCursor = nsCursor
    }
    init(image: CGImage, hotSpot: CGPoint) {
        self.image = image
        self.hotSpot = hotSpot
        self.nsCursor = NSCursor(image: NSImage(cgImage: image, size: NSSize()), hotSpot: hotSpot)
    }
    
    static func ==(lhs: Cursor, rhs: Cursor) -> Bool {
        return lhs.image === rhs.image && lhs.hotSpot == rhs.hotSpot
    }
}

struct TextInputContext {
    private static var currentContext: NSTextInputContext? {
        return NSTextInputContext.current
    }
    static func invalidateCharacterCoordinates() {
        currentContext?.invalidateCharacterCoordinates()
    }
    static func discardMarkedText() {
        currentContext?.discardMarkedText()
    }
}

extension URL {
    struct File {
        var url: URL, name: String, isExtensionHidden: Bool
    }
    static func file(message: String?,
                     name: String?,
                     fileTypes: [String],
                     completionHandler handler: @escaping (URL.File) -> (Void)) {
        guard let window = NSApp.mainWindow else {
            return
        }
        let savePanel = NSSavePanel()
        savePanel.message = message
        if let name = name {
            savePanel.nameFieldStringValue = name
        }
        savePanel.canSelectHiddenExtension = true
        savePanel.allowedFileTypes = fileTypes
        savePanel.beginSheetModal(for: window) { [unowned savePanel] result in
            if result == .OK, let url = savePanel.url {
                handler(URL.File(url: url,
                                 name: savePanel.nameFieldStringValue,
                                 isExtensionHidden: savePanel.isExtensionHidden))
            }
        }
    }
}

fileprivate struct C0DynamicCoder {
    static let appUTI = Bundle.main.bundleIdentifier ?? "smdls.C0."
    static func typeKey(from object: Any) -> String {
        return appUTI + String(describing: type(of: object))
    }
    static func typeKey<T>(from type: T.Type) -> String {
        return appUTI + String(describing: type)
    }
    static func decode(from data: Data, forKey key: String) -> Any? {
        if let object = NSKeyedUnarchiver.unarchiveObject(with: data) {
            return object
        }
        let decoder = JSONDecoder()
        switch key {
        case typeKey(from: Keyframe.self):
            return try? decoder.decode(Keyframe.self, from: data)
        case typeKey(from: Easing.self):
            return try? decoder.decode(Easing.self, from: data)
        case typeKey(from: Transform.self):
            return try? decoder.decode(Transform.self, from: data)
        case typeKey(from: Wiggle.self):
            return try? decoder.decode(Wiggle.self, from: data)
        case typeKey(from: Line.self):
            return try? decoder.decode(Line.self, from: data)
        case typeKey(from: Color.self):
            return try? decoder.decode(Color.self, from: data)
        case typeKey(from: URL.self):
            return try? decoder.decode(URL.self, from: data)
        default:
            return nil
        }
    }
    static func encode(_ object: Any, forKey key: String) -> Data? {
        if let coding = object as? NSCoding {
            return coding.data
        } else if let codable = object as? Encodable {
            return codable.jsonData
        } else {
            return nil
        }
    }
}

fileprivate struct C0Preference: Codable {
    var isFullScreen = false, windowFrame = NSRect()
}

@objc(C0Application)
final class C0Application: NSApplication {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyUp && event.modifierFlags.contains(.command) {
            keyWindow?.sendEvent(event)
        } else {
            super.sendEvent(event)
        }
    }
}

@NSApplicationMain final class C0AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var aboutAppItem: NSMenuItem?
    @IBOutlet weak var servicesItem: NSMenuItem?
    @IBOutlet weak var hideAppItem: NSMenuItem?
    @IBOutlet weak var hideOthersItem: NSMenuItem?
    @IBOutlet weak var showAllItem: NSMenuItem?
    @IBOutlet weak var quitAppItem: NSMenuItem?
    @IBOutlet weak var fileMenu: NSMenu?
    @IBOutlet weak var newItem: NSMenuItem?
    @IBOutlet weak var openItem: NSMenuItem?
    @IBOutlet weak var saveAsItem: NSMenuItem?
    @IBOutlet weak var openRecentItem: NSMenuItem?
    @IBOutlet weak var closeItem: NSMenuItem?
    @IBOutlet weak var saveItem: NSMenuItem?
    @IBOutlet weak var windowMenu: NSMenu?
    @IBOutlet weak var minimizeItem: NSMenuItem?
    @IBOutlet weak var zoomItem: NSMenuItem?
    @IBOutlet weak var bringAllToFrontItem: NSMenuItem?
    private var localToken: NSObjectProtocol?
    func applicationDidFinishLaunching(_ notification: Notification) {
        updateString(with: Locale.current)
        localToken = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: nil
        ) { [unowned self] _ in
            self.updateString(with: Locale.current)
        }
    }
    deinit {
        if let localToken = localToken {
            NotificationCenter.default.removeObserver(localToken)
        }
    }
    func updateString(with locale :Locale) {
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "C0"
        aboutAppItem?.title = Localization(english: "About \(appName)",
            japanese: "\(appName) について").string(with: locale)
        servicesItem?.title = Localization(english: "Services",
                                           japanese: "サービス").string(with: locale)
        hideAppItem?.title = Localization(english: "Hide \(appName)",
            japanese: "\(appName) を隠す").string(with: locale)
        hideOthersItem?.title = Localization(english: "Hide Others",
                                             japanese: "ほかを隠す").string(with: locale)
        showAllItem?.title = Localization(english: "Show All",
                                          japanese: "すべてを表示").string(with: locale)
        quitAppItem?.title = Localization(english: "Quit \(appName)",
            japanese: "\(appName) を終了").string(with: locale)
        fileMenu?.title = Localization(english: "File", japanese: "ファイル").string(with: locale)
        newItem?.title = Localization(english: "New", japanese: "新規").string(with: locale)
        openItem?.title = Localization(english: "Open…", japanese: "開く…").string(with: locale)
        saveAsItem?.title = Localization(english: "Save As…",
                                         japanese: "別名で保存…").string(with: locale)
        openRecentItem?.title = Localization(english: "Open Recent",
                                             japanese: "最近使った項目を開く").string(with: locale)
        closeItem?.title = Localization(english: "Close", japanese: "閉じる").string(with: locale)
        saveItem?.title = Localization(english: "Save…", japanese: "保存…").string(with: locale)
        windowMenu?.title = Localization(english: "Window", japanese: "ウインドウ").string(with: locale)
        minimizeItem?.title = Localization(english: "Minimize", japanese: "しまう").string(with: locale)
        zoomItem?.title = Localization(english: "Zoom", japanese: "拡大／縮小").string(with: locale)
        bringAllToFrontItem?.title = Localization(english: "Bring All to Front",
                                                  japanese: "すべてを手前に移動").string(with: locale)
    }
}

/**
 # Issue
 - NSDocument廃止
 - ファイルシステムのモードレス化
 */
final class C0Document: NSDocument, NSWindowDelegate {
    var rootDataModel: DataModel {
        didSet {
            let isWriteHandler: (DataModel, Bool) -> Void = { [unowned self] (dataModel, isWrite) in
                if isWrite {
                    self.updateChangeCount(.changeDone)
                }
            }
            
            if let preferenceDataModel = rootDataModel.children[C0Document.preferenceDataModelKey] {
                self.preferenceDataModel = preferenceDataModel
                if let preference: C0Preference = preferenceDataModel.readObject() {
                    self.preference = preference
                }
                preferenceDataModel.didChangeIsWriteHandler = isWriteHandler
                preferenceDataModel.dataHandler = { [unowned self] in self.preference.jsonData }
            } else {
                rootDataModel.insert(preferenceDataModel)
            }
        }
    }
    static let rootDataModelKey = "root", preferenceDataModelKey = "preference"
    var preferenceDataModel = DataModel(key: C0Document.preferenceDataModelKey)
    private var preference = C0Preference()
    
    var window: NSWindow {
        return windowControllers.first!.window!
    }
    weak var view: C0View!
    
    override init() {
        self.rootDataModel = DataModel(key: C0Document.rootDataModelKey,
                                       directoryWithDataModels: [preferenceDataModel])
        super.init()
        
        preferenceDataModel.dataHandler = { [unowned self] in return self.preference.jsonData }
    }
    convenience init(type typeName: String) throws {
        self.init()
        fileType = typeName
    }
    
    override class var autosavesInPlace: Bool {
        return true
    }
    
    override func makeWindowControllers() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "Document Window Controller")
        let windowController = storyboard
            .instantiateController(withIdentifier: identifier) as! NSWindowController
        addWindowController(windowController)
        view = windowController.contentViewController!.view as! C0View
        
        let isWriteHandler: (DataModel, Bool) -> Void = { [unowned self] (dataModel, isWrite) in
            if isWrite {
                self.updateChangeCount(.changeDone)
            }
        }
        if let humanDataModel = rootDataModel.children[Human.dataModelKey] {
            view.human.dataModel = humanDataModel
        } else if let humanDataModel = view.human.dataModel {
            rootDataModel.insert(humanDataModel)
        }
        
        if preference.windowFrame.isEmpty, let frame = NSScreen.main?.frame {
            let size = NSSize(width: 1132, height: 780)
            let origin = NSPoint(x: round((frame.width - size.width) / 2),
                                 y: round((frame.height - size.height) / 2))
            preference.windowFrame = NSRect(origin: origin, size: size)
        }
        setupWindow(with: preference)
        
        undoManager = view.human.sceneEditor.undoManager
        
        view.human.preferenceDataModel.didChangeIsWriteHandler = isWriteHandler
        view.human.sceneEditor.sceneDataModel.didChangeIsWriteHandler = isWriteHandler
        preferenceDataModel.didChangeIsWriteHandler = isWriteHandler
        
        view.human.copiedObjectEditor.copiedObject = copiedObject(with: NSPasteboard.general)
    }
    private func setupWindow(with preference: C0Preference) {
        window.setFrame(preference.windowFrame, display: false)
        if preference.isFullScreen {
            window.toggleFullScreen(nil)
        }
        window.delegate = self
    }
    
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        rootDataModel.writeAllFileWrappers()
        return rootDataModel.fileWrapper
    }
    override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        rootDataModel = DataModel(key: C0Document.rootDataModelKey, fileWrapper: fileWrapper)
    }
    
    func windowDidResize(_ notification: Notification) {
        preference.windowFrame = window.frame
        preferenceDataModel.isWrite = true
    }
    func windowDidMove(_ notification: Notification) {
        preference.windowFrame = window.frame
        preferenceDataModel.isWrite = true
    }
    func windowDidEnterFullScreen(_ notification: Notification) {
        preference.isFullScreen = true
        preferenceDataModel.isWrite = true
    }
    func windowDidExitFullScreen(_ notification: Notification) {
        preference.isFullScreen = false
        preferenceDataModel.isWrite = true
    }
    
    var oldChangeCountWithCopiedObject = 0
    var oldChangeCountWithPsteboard = NSPasteboard.general.changeCount
    func windowDidBecomeMain(_ notification: Notification) {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != oldChangeCountWithPsteboard {
            oldChangeCountWithPsteboard = pasteboard.changeCount
            view.human.copiedObjectEditor.copiedObject = copiedObject(with: pasteboard)
            oldChangeCountWithCopiedObject = view.human.copiedObjectEditor.changeCount
        }
    }
    func windowDidResignMain(_ notification: Notification) {
        if oldChangeCountWithCopiedObject != view.human.copiedObjectEditor.changeCount {
            oldChangeCountWithCopiedObject = view.human.copiedObjectEditor.changeCount
            let pasteboard = NSPasteboard.general
            setCopiedObject(view.human.copiedObjectEditor.copiedObject, in: pasteboard)
            oldChangeCountWithPsteboard = pasteboard.changeCount
        }
    }
    func copiedObject(with pasteboard: NSPasteboard) -> CopiedObject {
        var copiedObject = CopiedObject()
        func append(with data: Data, type: NSPasteboard.PasteboardType) {
            if let object = C0DynamicCoder.decode(from: data, forKey: type.rawValue) {
                copiedObject.objects.append(object)
            }
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: nil) as? [URL], !urls.isEmpty {
            urls.forEach { copiedObject.objects.append($0) }
        }
         if let string = pasteboard.string(forType: .string) {
            copiedObject.objects.append(string)
        } else if let types = pasteboard.types {
            for type in types {
                if let data = pasteboard.data(forType: type) {
                    append(with: data, type: type)
                } else if let string = pasteboard.string(forType: .string) {
                    copiedObject.objects.append(string)
                }
            }
        } else if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        append(with: data, type: type)
                    } else if let string = item.string(forType: .string) {
                        copiedObject.objects.append(string)
                    }
                }
            }
        }
        return copiedObject
    }
    func setCopiedObject(_ copiedObject: CopiedObject, in pasteboard: NSPasteboard) {
        guard !copiedObject.objects.isEmpty else {
            pasteboard.clearContents()
            return
        }
        var strings = [String]()
        var typesAndDatas = [(type: NSPasteboard.PasteboardType, data: Data)]()
        for object in copiedObject.objects {
            if let string = object as? String {
                strings.append(string)
            } else {
                let type = C0DynamicCoder.typeKey(from: object)
                if let data = C0DynamicCoder.encode(object, forKey: type) {
                    typesAndDatas.append((NSPasteboard.PasteboardType(rawValue: type), data))
                }
            }
        }
        
        if strings.count == 1, let string = strings.first {
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(string, forType: .string)
        } else if typesAndDatas.count == 1, let typeAndData = typesAndDatas.first {
            pasteboard.declareTypes([typeAndData.type], owner: nil)
            pasteboard.setData(typeAndData.data, forType: typeAndData.type)
        } else {
            var items = [NSPasteboardItem]()
            for string in strings {
                let item = NSPasteboardItem()
                item.setString(string, forType: .string)
                items.append(item)
            }
            for typeAndData in typesAndDatas {
                let item = NSPasteboardItem()
                item.setData(typeAndData.data, forType: typeAndData.type)
                items.append(item)
            }
            pasteboard.clearContents()
            pasteboard.writeObjects(items)
        }
    }
    
    @IBAction func readme(_ sender: Any?) {
        if let url = URL(string: "https://github.com/smdls/C0") {
            NSWorkspace.shared.open(url)
        }
    }
    func openEmoji() {
        NSApp.orderFrontCharacterPalette(nil)
    }
}

final class C0View: NSView, NSTextInputClient {
    let human = Human()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    private var token: NSObjectProtocol?, localToken: NSObjectProtocol?
    override func makeBackingLayer() -> CALayer {
        return backingLayer(with: human.vision)
    }
    func setup() {
        acceptsTouchEvents = true
        wantsLayer = true
        guard let layer = layer else {
            return
        }
        human.vision.allChildrenAndSelf { $0.contentsScale = layer.contentsScale }
        human.setCursorHandler = {
            if $0.cursor.nsCursor != NSCursor.current {
                $0.cursor.nsCursor.set()
            }
        }
        
        let nc = NotificationCenter.default
        localToken = nc.addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                                    object: nil,
                                    queue: nil) { [unowned self] _ in self.human.locale = .current }
        token = nc.addObserver(forName: NSView.frameDidChangeNotification,
                               object: self,
                               queue: nil) { ($0.object as? C0View)?.updateFrame() }
    }
    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
        if let localToken = localToken {
            NotificationCenter.default.removeObserver(localToken)
        }
    }
    override var acceptsFirstResponder: Bool {
        return true
    }
    override func becomeFirstResponder() -> Bool {
        return true
    }
    override func resignFirstResponder() -> Bool {
        return true
    }
    
    override func viewDidChangeBackingProperties() {
        if let backingScaleFactor = window?.backingScaleFactor {
            Screen.shared.backingScaleFactor = backingScaleFactor
            human.contentsScale = backingScaleFactor
        }
    }
    
    func createTrackingArea() {
        let options: NSTrackingArea.Options = [.activeInKeyWindow,
                                               .mouseMoved, .mouseEnteredAndExited]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self))
    }
    override func updateTrackingAreas() {
        trackingAreas .forEach { removeTrackingArea($0) }
        createTrackingArea()
        super.updateTrackingAreas()
    }
    
    func updateFrame() {
        human.fieldOfVision = bounds.size
    }
    
    func screenPoint(with event: NSEvent) -> CGPoint {
        return convertToLayer(convert(event.locationInWindow, from: nil))
    }
    var cursorPoint: CGPoint {
        guard let window = window else {
            return NSPoint()
        }
        let windowPoint = window.mouseLocationOutsideOfEventStream
        return convertToLayer(convert(windowPoint, from: nil))
    }
    func convertFromTopScreen(_ p: NSPoint) -> NSPoint {
        guard let window = window else {
            return NSPoint()
        }
        let windowPoint = window.convertFromScreen(NSRect(origin: p, size: NSSize())).origin
        return convertToLayer(convert(windowPoint, from: nil))
    }
    func convertToTopScreen(_ r: CGRect) -> NSRect {
        guard let window = window else {
            return NSRect()
        }
        return convertFromLayer(window.convertToScreen(convert(r, to: nil)))
    }
    
    func quasimodeEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> MoveEvent {
        return MoveEvent(sendType: sendType, location: cursorPoint,
                         time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil)
    }
    func moveEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> MoveEvent {
        return MoveEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                         time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil)
    }
    func dragEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> DragEvent {
        return DragEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                         time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil,
                         pressure: nsEvent.pressure.cf)
    }
    func scrollEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> ScrollEvent {
        return ScrollEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                           time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil,
                           scrollDeltaPoint: CGPoint(x: nsEvent.scrollingDeltaX,
                                                     y: -nsEvent.scrollingDeltaY),
                           scrollMomentumType: nsEvent.scrollMomentumType,
                           beginNormalizedPosition: beginTouchesNormalizedPosition)
    }
    func pinchEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> PinchEvent {
        return PinchEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                          time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil,
                          magnification: nsEvent.magnification)
    }
    func rotateEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> RotateEvent {
        return RotateEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                           time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil,
                           rotation: nsEvent.rotation.cf)
    }
    func tapEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> TapEvent {
        return TapEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                        time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil)
    }
    func doubleTapEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> DoubleTapEvent {
        return DoubleTapEvent(sendType: sendType, location: screenPoint(with: nsEvent),
                              time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nil)
    }
    func keyInputEventWith(_ sendType: Action.SendType, _ nsEvent: NSEvent) -> KeyInputEvent {
        return KeyInputEvent(sendType: sendType, location: cursorPoint,
                             time: nsEvent.timestamp, quasimode: nsEvent.quasimode, key: nsEvent.key)
    }
    
    override func flagsChanged(with event: NSEvent) {
        let quasimode = quasimodeEventWith(!event.modifierFlags.isEmpty ? .begin : .end, event)
        human.sendEditQuasimode(with: quasimode)
    }
    
    override func keyDown(with event: NSEvent) {
        keyInput(with: event, .begin)
    }
    override func keyUp(with event: NSEvent) {
        keyInput(with: event, .end)
    }
    private func keyInput(with event: NSEvent, _ sendType: Action.SendType) {
        if human.sendKeyInputIsEditText(with: keyInputEventWith(sendType, event)) {
            inputContext?.handleEvent(event)
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        human.sendMoveCursor(with: moveEventWith(.begin, event))
        if human.indicatedResponder.cursor.nsCursor != NSCursor.current {
            human.indicatedResponder.cursor.nsCursor.set()
        }
    }
    override func mouseExited(with event: NSEvent) {
        human.sendMoveCursor(with: moveEventWith(.end, event))
    }
    override func mouseMoved(with event: NSEvent) {
        human.sendMoveCursor(with: moveEventWith(.sending, event))
    }
    
    override func rightMouseDown(with nsEvent: NSEvent) {
        human.sendRightDrag(with: dragEventWith(.begin, nsEvent))
    }
    override func rightMouseDragged(with nsEvent: NSEvent) {
        human.sendRightDrag(with: dragEventWith(.sending, nsEvent))
    }
    override func rightMouseUp(with nsEvent: NSEvent) {
        human.sendRightDrag(with: dragEventWith(.end, nsEvent))
    }
    
    override func mouseDown(with nsEvent: NSEvent) {
        human.sendDrag(with: dragEventWith(.begin, nsEvent))
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        human.sendDrag(with: dragEventWith(.sending, nsEvent))
    }
    override func mouseUp(with nsEvent: NSEvent) {
        human.sendDrag(with: dragEventWith(.end, nsEvent))
    }
    
    private var beginTouchesNormalizedPosition = CGPoint()
    override func touchesBegan(with event: NSEvent) {
        let touches = event.touches(matching: .began, in: self)
        beginTouchesNormalizedPosition = touches.reduce(CGPoint()) {
            return CGPoint(x: max($0.x, $1.normalizedPosition.x),
                           y: max($0.y, $1.normalizedPosition.y))
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.phase != .mayBegin && event.phase != .cancelled {
            let momentum = event.momentumPhase == .changed || event.momentumPhase == .ended
            let sendType: Action.SendType = event.phase == .began ?
                .begin : (event.phase == .ended ? .end : .sending)
            human.sendScroll(with: scrollEventWith(sendType, event), momentum: momentum)
        }
    }
    
    private enum TouchGesture {
        case none, scroll, pinch, rotate
    }
    private var blockGesture = TouchGesture.none
    override func magnify(with event: NSEvent) {
        if event.phase == .began {
            if blockGesture == .none {
                blockGesture = .pinch
                human.sendZoom(with: pinchEventWith(.begin, event))
            }
        } else if event.phase == .ended {
            if blockGesture == .pinch {
                blockGesture = .none
                human.sendZoom(with:pinchEventWith(.end, event))
            }
        } else {
            if blockGesture == .pinch {
                human.sendZoom(with: pinchEventWith(.sending, event))
            }
        }
    }
    override func rotate(with event: NSEvent) {
        if event.phase == .began {
            if blockGesture == .none {
                blockGesture = .rotate
                human.sendRotate(with: rotateEventWith(.begin, event))
            }
        } else if event.phase == .ended {
            if blockGesture == .rotate {
                blockGesture = .none
                human.sendRotate(with: rotateEventWith(.end, event))
            }
        } else {
            if blockGesture == .rotate {
                human.sendRotate(with: rotateEventWith(.sending, event))
            }
        }
    }
    
    override func quickLook(with event: NSEvent) {
        human.sendLookup(with: tapEventWith(.end, event))
    }
    override func smartMagnify(with event: NSEvent) {
        human.sendResetView(with: doubleTapEventWith(.end, event))
    }
    
    var editTextEditor: TextEditor? {
        return human.editTextEditor
    }
    func hasMarkedText() -> Bool {
        return editTextEditor?.hasMarkedText ?? false
    }
    func markedRange() -> NSRange {
        return editTextEditor?.markedRange ?? NSRange(location: NSNotFound, length: 0)
    }
    func selectedRange() -> NSRange {
        return editTextEditor?.selectedRange ?? NSRange(location: NSNotFound, length: 0)
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        editTextEditor?.setMarkedText(string, selectedRange: selectedRange,
                                      replacementRange: replacementRange)
    }
    func unmarkText() {
        editTextEditor?.unmarkText()
    }
    func validAttributesForMarkedText() -> [NSAttributedStringKey] {
        return [.markedClauseSegment, .glyphInfo]
    }
    func attributedSubstring(forProposedRange range: NSRange,
                             actualRange: NSRangePointer?) -> NSAttributedString? {
        return editTextEditor?.attributedSubstring(forProposedRange: range, actualRange: actualRange)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        editTextEditor?.insertText(string, replacementRange: replacementRange)
    }
    func characterIndex(for point: NSPoint) -> Int {
        if let editText = editTextEditor {
            let p = editText.convert(convertFromTopScreen(point), from: nil)
            return editText.characterIndex(for: p)
        } else {
            return 0
        }
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        if let editText = editTextEditor {
            let rect = editText.firstRect(forCharacterRange: range, actualRange: actualRange)
            return convertToTopScreen(editText.convert(rect, to: nil))
        } else {
            return NSRect()
        }
    }
    func attributedString() -> NSAttributedString {
        return editTextEditor?.attributedString ?? NSAttributedString()
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> CGFloat {
        if let editText = editTextEditor {
            let p = editText.convert(convertFromTopScreen(point), from: nil)
            return editText.characterFraction(for: p)
        } else {
            return 0
        }
    }
    func baselineDeltaForCharacter(at anIndex: Int) -> CGFloat {
        return editTextEditor?.baselineDelta(at: anIndex) ?? 0
    }
    func windowLevel() -> Int {
        return window?.level.rawValue ?? 0
    }
    func drawsVerticallyForCharacter(at charIndex: Int) -> Bool {
        return false
    }
    
    override func insertNewline(_ sender: Any?) {
        editTextEditor?.insertNewline()
    }
    override func insertTab(_ sender: Any?) {
        editTextEditor?.insertTab()
    }
    override func deleteBackward(_ sender: Any?) {
        editTextEditor?.deleteBackward()
    }
    override func deleteForward(_ sender: Any?) {
        editTextEditor?.deleteForward()
    }
    override func moveLeft(_ sender: Any?) {
        editTextEditor?.moveLeft()
    }
    override func moveRight(_ sender: Any?) {
        editTextEditor?.moveRight()
    }
}

extension NSImage {
    convenience init(size: CGSize, handler: (CGContext) -> Void) {
        self.init(size: size)
        lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            handler(ctx)
        }
        unlockFocus()
    }
    final var bitmapSize: CGSize {
        if let tiffRepresentation = tiffRepresentation {
            if let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
                return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
            }
        }
        return CGSize()
    }
    final var PNGRepresentation: Data? {
        if let tiffRepresentation = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffRepresentation) {
            
            return bitmap.representation(using: .png, properties: [.interlaced: false])
        } else {
            return nil
        }
    }
    static func exportAppIcon() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.begin { [unowned panel] result in
            guard result.rawValue == NSFileHandlingPanelOKButton, let url = panel.url else {
                return
            }
            for width in [16.0.cf, 32.0.cf, 64.0.cf, 128.0.cf, 256.0.cf, 512.0.cf, 1024.0.cf] {
                let size = CGSize(width: width, height: width)
                let image = NSImage(size: size, flipped: false) { rect -> Bool in
                    let ctx = NSGraphicsContext.current!.cgContext
                    let c = width * 0.5, r = width * 0.43, l = width * 0.008, fs = width * 0.45
                    ctx.setFillColor(Color.white.cgColor)
                    ctx.setStrokeColor(Color.locked.cgColor)
                    ctx.setLineWidth(l)
                    ctx.addEllipse(in: CGRect(x: c - r, y: c - r, width: r * 2, height: r * 2))
                    ctx.drawPath(using: .fillStroke)
                    let textFrame = TextFrame(
                        string: "C0", font: Font(name: "Avenir Next Regular", size: fs),
                        color: .locked
                    )
                    textFrame.drawWithCenterOfImageBounds(in: rect, in: ctx)
                    return true
                }
                try? image.PNGRepresentation?
                    .write(to: url.appendingPathComponent("\(String(Int(width))).png"))
            }
        }
    }
}

extension NSEvent {
    var quasimode: Action.Quasimode {
        var quasimode: Action.Quasimode = []
        if modifierFlags.contains(.shift) {
            quasimode.insert(.shift)
        }
        if modifierFlags.contains(.command) {
            quasimode.insert(.command)
        }
        if modifierFlags.contains(.control) {
            quasimode.insert(.control)
        }
        if modifierFlags.contains(.option) {
            quasimode.insert(.option)
        }
        return quasimode
    }
    var scrollMomentumType: Action.SendType? {
        if momentumPhase.contains(.began) {
            return .begin
        } else if momentumPhase.contains(.changed) {
            return .sending
        } else if momentumPhase.contains(.ended) {
            return .end
        } else {
            return nil
        }
    }
    var key: Action.Key? {
        switch keyCode {
        case 0:
            return .a
        case 1:
            return .s
        case 2:
            return .d
        case 3:
            return .f
        case 4:
            return .h
        case 5:
            return .g
        case 6:
            return .z
        case 7:
            return .x
        case 8:
            return .c
        case 9:
            return .v
        case 11:
            return .b
        case 12:
            return .q
        case 13:
            return .w
        case 14:
            return .e
        case 15:
            return .r
        case 16:
            return .y
        case 17:
            return .t
        case 18:
            return .no1
        case 19:
            return .no2
        case 20:
            return .no3
        case 21:
            return .no4
        case 22:
            return .no6
        case 23:
            return .no5
        case 24:
            return .equals
        case 25:
            return .no9
        case 26:
            return .no7
        case 27:
            return .minus
        case 28:
            return .no8
        case 29:
            return .no0
        case 30:
            return .rightBracket
        case 31:
            return .o
        case 32:
            return .u
        case 33:
            return .leftBracket
        case 34:
            return .i
        case 35:
            return .p
        case 36:
            return .return
        case 37:
            return .l
        case 38:
            return .j
        case 39:
            return .apostrophe
        case 40:
            return .k
        case 41:
            return .semicolon
        case 42:
            return .frontslash
        case 43:
            return .comma
        case 44:
            return .backslash
        case 45:
            return .n
        case 46:
            return .m
        case 47:
            return .period
        case 48:
            return .tab
        case 49:
            return .space
        case 50:
            return .backApostrophe
        case 51:
            return .delete
        case 53:
            return .escape
        case 55:
            return .command
        case 56:
            return .shiht
        case 58:
            return .option
        case 59:
            return .control
        case 123:
            return .left
        case 124:
            return .right
        case 125:
            return .down
        case 126:
            return .up
        default:
            return nil
        }
    }
}
