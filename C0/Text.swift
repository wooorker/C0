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
//TextEditorを完成させる（タイムラインのスクロール設計と同等）
//TextEditorとLabelを統合
//モードレス・テキスト入力（すべての状態において、キー入力を受け付ける。コマンドとの衝突が問題）
//CoreText

import Foundation
import QuartzCore

protocol TextInput {
}

final class Text: NSObject, NSCoding {
    let string: String
    
    init(string: String = "") {
        self.string = string
        super.init()
    }
    
    static let dataType = "C0.Text.1", stringKey = "0"
    init?(coder: NSCoder) {
        string = coder.decodeObject(forKey: Text.stringKey) as? String ?? ""
        super.init()
    }
    func encode(with coder: NSCoder) {
        coder.encode(string, forKey: Text.stringKey)
    }
    
    var isEmpty: Bool {
        return string.isEmpty
    }
    let borderColor = SceneDefaults.speechBorderColor, fillColor = SceneDefaults.speechFillColor
    func draw(bounds: CGRect, in ctx: CGContext) {
        let attString = NSAttributedString(string: string, attributes: [
            String(kCTFontAttributeName): SceneDefaults.speechFont,
            String(kCTForegroundColorFromContextAttributeName): true
            ])
        let framesetter = CTFramesetterCreateWithAttributedString(attString)
        let range = CFRange(location: 0, length: attString.length), ratio = bounds.size.width/640
        let lineBounds = CGRect(origin: CGPoint(), size: CTFramesetterSuggestFrameSizeWithConstraints(framesetter, range, nil, CGSize(width: CGFloat.infinity, height: CGFloat.infinity), nil))
        let ctFrame = CTFramesetterCreateFrame(framesetter, range, CGPath(rect: lineBounds, transform: nil), nil)
        ctx.saveGState()
        ctx.translateBy(x: round(bounds.midX - lineBounds.midX),  y: round(bounds.minY + 20*ratio))
        ctx.setTextDrawingMode(.stroke)
        ctx.setLineWidth(ceil(3*ratio))
        ctx.setStrokeColor(borderColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.setTextDrawingMode(.fill)
        ctx.setFillColor(fillColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.restoreGState()
    }
}
protocol TextEditorDelegate: class {
    func changeText(textEditor: TextEditor, string: String, oldString: String, type: Action.SendType)
}
final class TextEditor: LayerRespondable, TextInput {
    static let type = ObjectType(identifier: "TextEditor", name: Localization(english: "Text Editor", japanese: "テキスト・エディタ"))
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: TextEditorDelegate?

    var backingStore = NSMutableAttributedString()
//    var defaultAttributes = NSAttributedString.attributes(NSFont.labelFont(ofSize: 11), color: Defaults.contentEditColor.cgColor)
//    var markedAttributes = NSAttributedString.attributes(NSFont.labelFont(ofSize: 11), color: NSColor.lightGray.cgColor)
//    
////    var layoutManager = NSLayoutManager()
////    var textContainer = NSTextContainer()
    
    private var _markedRange = NSRange(location: 0, length: 0) {
        didSet{
            updateTextLine()
        }
    }
    private var _selectedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            updateTextLine()
        }
    }

    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(fillColor: Defaults.subBackgroundColor.cgColor)
    
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }

////    var inputContext: NSTextInputContext? {
////        return screen?.inputContext
////    }
//    
    init(frame: CGRect = CGRect()) {
        textLine = TextLine()
        
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
//        layer.frame = frame
//        backingStore = NSTextStorage(string: "", attributes: defaultAttributes)
//        backingStore.addLayoutManager(layoutManager)
//        layoutManager.addTextContainer(textContainer)
    }
    
    func updateTextLine() {
        textLine.attributedString = backingStore
    }
    
    func draw(in ctx: CGContext) {
        ////        let rect = ctx.boundingBoxOfClipPath
        ////        let ctLine = CTLineCreateWithAttributedString()
    }
//
//    func cursor(with p: CGPoint) -> NSCursor {
//        return NSCursor.iBeam()
//    }
//    
//    var frame: CGRect {
//        didSet {
//            textContainer.containerSize = frame.size
//            layer.setNeedsDisplay()
//        }
//    }
//    
    var string: String {
        get {
            return backingStore.string
        }
        set {
//            backingStore.beginEditing()
//            backingStore.replaceCharacters(in: NSRange(location: 0, length: backingStore.length), with: newValue)
//            backingStore.setAttributes(defaultAttributes, range: NSRange(location: 0, length: (newValue as NSString).length))
//            backingStore.endEditing()
//            unmarkText()
//            
//            _selectedRange = NSRange(location: (newValue as NSString).length, length: 0)
//            inputContext?.invalidateCharacterCoordinates()
//            
//            updateTextLine()
        }
    }
//
//    func delete() {
//        deleteBackward()
//    }
//    
//    func copy() {
//        screen?.copy(string, forType: NSStringPboardType, from: self)
//    }
//    func paste() {
//        let pasteboard = NSPasteboard.general()
//        if let string = pasteboard.string(forType: NSPasteboardTypeString) {
//            let oldString = string
//            delegate?.changeText(textEditor: self, string: string, oldString: oldString, type: .begin)
//            self.string = string
//            delegate?.changeText(textEditor: self, string: string, oldString: oldString, type: .end)
//        }
//    }
//    
//    private let timer = LockTimer()
//    private var oldText = ""
    func keyInput(with event: KeyInputEvent) {
//        timer.begin(1, beginHandler: { [unowned self] in
//            self.oldText = self.string
//            self.delegate?.changeText(textEditor: self, string: self.string, oldString: self.oldText, type: .begin)
//            }, endHandler: { [unowned self] in
//                self.delegate?.changeText(textEditor: self, string: self.string, oldString: self.oldText, type: .end)
//        })
//        screen?.inputContext?.handleEvent(event)
    }

//    func lookUp(with event: TapEvent) {
//        let p = point(with: event)
//        let string = self.backingStore.string as NSString
//        let glyphIndex = layoutManager.glyphIndex(for: p, in: textContainer, fractionOfDistanceThroughGlyph: nil)
//        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
//        var range = NSRange()
//        if characterIndex >= _selectedRange.location && characterIndex < NSMaxRange(_selectedRange) {
//            range = _selectedRange
//        } else {
//            let allRange = NSRange(location: 0, length: string.length)
//            string.enumerateSubstrings(in: allRange, options: .byWords) { substring, substringRange, enclosingRange, stop in
//                if characterIndex >= substringRange.location && characterIndex < NSMaxRange(substringRange) {
//                    range = substringRange
//                    stop.pointee = true
//                }
//            }
//        }
//        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
//        let ap = convert(toScreen: layoutManager.location(forGlyphAt: glyphRange.location))
//        if range.length > 0 {
//            screen?.showDefinition(for: backingStore.attributedSubstring(from: range), at: ap)
//        }
//        else {
//            screen?.tempNotAction()
//        }
//    }
//    
    func insertNewline() {
//        insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    func insertTab() {
//        insertText("\t", replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    func deleteBackward() {
//        var deleteRange = _selectedRange
//        if deleteRange.length == 0 {
//            if deleteRange.location == 0 {
//                return
//            } else {
//                deleteRange.location -= 1
//                deleteRange.length = 1
//                deleteRange = (backingStore.string as NSString).rangeOfComposedCharacterSequences(for: deleteRange)
//            }
//        }
//        deleteCharacters(in: deleteRange)
    }
    func deleteForward() {
//        var deleteRange = _selectedRange
//        if deleteRange.length == 0 {
//            if deleteRange.location == backingStore.length {
//                return
//            } else {
//                deleteRange.length = 1
//                deleteRange = (backingStore.string as NSString).rangeOfComposedCharacterSequences(for: deleteRange)
//            }
//        }
//        deleteCharacters(in: deleteRange)
    }
    func moveLeft() {
//        if _selectedRange.length > 0 {
//            _selectedRange.length = 0
//        } else if _selectedRange.location > 0 {
//            _selectedRange.location -= 1
//        }
    }
    func moveRight() {
//        if _selectedRange.length > 0 {
//            _selectedRange = NSRange(location: NSMaxRange(_selectedRange), length: 0)
//        } else if _selectedRange.location > 0 {
//            _selectedRange.location += 1
//        }
    }

//    func deleteCharacters(in range: NSRange) {
//        if NSLocationInRange(NSMaxRange(range), _markedRange) {
//            _markedRange = NSRange(location: range.location, length: _markedRange.length - (NSMaxRange(range) - _markedRange.location))
//        } else {
//            _markedRange.location -= range.length
//        }
//        if _markedRange.length == 0 {
//            unmarkText()
//        }
//        backingStore.deleteCharacters(in: range)
//        _selectedRange = NSRange(location: range.location, length: 0)
//        inputContext?.invalidateCharacterCoordinates()
//        
//        updateTextLine()
//    }
    
    func hasMarkedText() -> Bool {
        return _markedRange.location != NSNotFound
    }
    func markedRange() -> NSRange {
        return _markedRange
    }
    func selectedRange() -> NSRange {
        return _selectedRange
    }
//
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
//        let aReplacementRange = _markedRange.location != NSNotFound ? _markedRange : _selectedRange
//        backingStore.beginEditing()
//        if let attString = string as? NSAttributedString {
//            if attString.length == 0 {
//                backingStore.deleteCharacters(in: aReplacementRange)
//                unmarkText()
//            } else {
//                _markedRange = NSRange(location: aReplacementRange.location, length: attString.length)
//                backingStore.replaceCharacters(in: aReplacementRange, with: attString)
//                backingStore.addAttributes(markedAttributes, range: _markedRange)
//            }
//        } else if let string = string as? String {
//            if (string as NSString).length == 0 {
//                backingStore.deleteCharacters(in: aReplacementRange)
//                unmarkText()
//            } else {
//                _markedRange = NSRange(location: aReplacementRange.location, length: (string as NSString).length)
//                backingStore.replaceCharacters(in: aReplacementRange, with: string)
//                backingStore.addAttributes(markedAttributes, range: _markedRange)
//            }
//        }
//        backingStore.endEditing()
//        
//        _selectedRange = NSRange(location: aReplacementRange.location + selectedRange.location, length: selectedRange.length)
//        inputContext?.invalidateCharacterCoordinates()
//        
//        updateTextLine()
    }
    func unmarkText() {
//        _markedRange = NSRange(location: NSNotFound, length: 0)
//        inputContext?.discardMarkedText()
    }
    
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = range
        return backingStore.attributedSubstring(from: range)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
//        let replaceRange: NSRange
//        if replacementRange.location != NSNotFound {
//            replaceRange = replacementRange
//        } else {
//            replaceRange = _markedRange.location != NSNotFound ? _markedRange : _selectedRange
//        }
//        backingStore.beginEditing()
//        if let attString = string as? NSAttributedString {
//            backingStore.replaceCharacters(in: replaceRange, with: attString)
//            backingStore.setAttributes(defaultAttributes, range: NSRange(location: replaceRange.location, length: attString.length))
//        } else if let string = string as? String {
//            backingStore.replaceCharacters(in: replaceRange, with: string)
//            backingStore.setAttributes(defaultAttributes, range: NSRange(location: replaceRange.location, length: (string as NSString).length))
//        }
//        backingStore.endEditing()
//        
//        _selectedRange = NSRange(location: backingStore.length, length: 0)
//        unmarkText()
//        inputContext?.invalidateCharacterCoordinates()
//        
//        updateTextLine()
    }

    func characterIndex(for point: NSPoint) -> Int {
        return 0
//        let p = convert(fromScreen: screen?.convertFromTopScreen(point) ?? NSPoint())
//        let glyphIndex = layoutManager.glyphIndex(for: p, in: textContainer, fractionOfDistanceThroughGlyph: nil)
//        return layoutManager.characterIndexForGlyph(at: glyphIndex)
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        return NSRect()
//        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: actualRange)
//        let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
//        return screen?.convertToTopScreen(convert(toScreen: glyphRect)) ?? NSRect()
    }
    func attributedString() -> NSAttributedString {
        return backingStore
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> CGFloat {
        return 0.5
//        let p = convert(fromScreen: screen?.convertFromTopScreen(point) ?? NSPoint())
//        var fraction = 0.5.cf
//        layoutManager.glyphIndex(for: p, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
//        return fraction
    }
    func baselineDeltaForCharacter(at anIndex: Int) -> CGFloat {
        return 0
    }
}
final class Label: LayerRespondable, Localizable {
    static let type = ObjectType(identifier: "Label", name: Localization(english: "Label", japanese: "ラベル"))
    var description: Localization
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children)
        }
    }
    var undoManager: UndoManager?
    var locale = Locale.current {
        didSet {
            CATransaction.disableAnimation {
                textLine.string = text.string(with: locale)
                if isSizeToFit {
                    sizeToFit(withHeight: bounds.height)
                }
            }
        }
    }
    
    var text = Localization()
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    var isSizeToFit = false
    var layer :CALayer {
        return drawLayer
    }
    let drawLayer: DrawLayer
    
    let highlight = Highlight()
    
    init(frame: CGRect = CGRect(), text: Localization, textLine: TextLine = TextLine(), backgroundColor: CGColor = Defaults.subBackgroundColor.cgColor, isSizeToFit: Bool = false, description: Localization = Localization()) {
        self.description = description.isEmpty ? text : description
        self.drawLayer = DrawLayer(fillColor: backgroundColor)
        self.text = text
        self.textLine = textLine
        self.isSizeToFit = isSizeToFit
        layer.borderWidth = 0
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        drawLayer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        drawLayer.addSublayer(highlight.layer)
    }
    convenience init(string: String, font: CTFont = Defaults.labelFont, color: CGColor = Defaults.fontColor.cgColor, backgroundColor: CGColor = Defaults.subBackgroundColor.cgColor, paddingWidth: CGFloat = 6, width: CGFloat? = nil, height: CGFloat? = nil) {
        let text = Localization(string)
        let textLine = TextLine(string: text.currentString, font: font, color: color, paddingWidth: paddingWidth, isHorizontalCenter: true)
        let frame = CGRect(x: 0, y: 0, width: ceil(textLine.stringBounds.width + paddingWidth*2), height: height ?? textLine.imageBounds.height)
        self.init(frame: frame, text: text, textLine: textLine, backgroundColor: backgroundColor, isSizeToFit: true)
    }
    convenience init(text: Localization = Localization(), font: CTFont = Defaults.labelFont, color: CGColor = Defaults.fontColor.cgColor, backgroundColor: CGColor = Defaults.subBackgroundColor.cgColor, paddingWidth: CGFloat = 6, width: CGFloat? = nil, height: CGFloat? = nil) {
        let textLine = TextLine(string: text.currentString, font: font, color: color, paddingWidth: paddingWidth, isHorizontalCenter: true)
        let frame = CGRect(x: 0, y: 0, width: ceil(textLine.stringBounds.width + paddingWidth*2), height: height ?? textLine.imageBounds.height)
        self.init(frame: frame, text: text, textLine: textLine, backgroundColor: backgroundColor, isSizeToFit: true)
    }
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(strings: [textLine.string])
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            highlight.layer.frame = bounds.inset(by: 0.5)
        }
    }
    
    func sizeToFit(withHeight height: CGFloat) {
        let oldWidth = layer.bounds.width
        layer.bounds = CGRect(x: 0, y: 0, width: ceil(textLine.stringBounds.width + textLine.paddingSize.width*2), height: height)
        if textLine.alignment == .right {
            layer.frame.origin.x -= layer.bounds.width - oldWidth
        }
    }
}

struct TextLine {
    init(string: String = "", font: CTFont = Defaults.font, color: CGColor = Defaults.fontColor.cgColor,
         paddingWidth: CGFloat = 6, paddingHeight: CGFloat = 6, alignment: CTTextAlignment = CTTextAlignment.natural,
         isHorizontalCenter: Bool = false, isVerticalCenter: Bool = true, isCenterWithImageBounds: Bool = false) {
        
        line = CTLineCreateWithAttributedString(attributedString)
        self.font = font
        self.color = color
        self.paddingSize = CGSize(width: paddingWidth, height: paddingHeight)
        self.alignment = alignment
        self.isHorizontalCenter = isHorizontalCenter
        self.isVerticalCenter = isVerticalCenter
        self.isCenterWithImageBounds = isCenterWithImageBounds
        updateAttributedString(string: string, font: font, color: color, alignment: alignment)
    }
    var line: CTLine, textFrame: CTFrame?
    
    var string: String {
        get {
            return attributedString.string
        }
        set {
            updateAttributedString(string: newValue, font: font, color: color, alignment: alignment)
        }
    }
    var font: CTFont {
        didSet {
            updateAttributedString(string: string, font: font, color: color, alignment: alignment)
        }
    }
    var color: CGColor {
        didSet {
            updateAttributedString(string: string, font: font, color: color, alignment: alignment)
        }
    }
    var alignment: CTTextAlignment
    private mutating func updateAttributedString(string: String, font: CTFont, color: CGColor, alignment: CTTextAlignment) {
        var alignment = alignment
        let settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &alignment)]
        let style = CTParagraphStyleCreate(settings, settings.count)
        attributedString = NSAttributedString(string: string, attributes: [
            String(kCTFontAttributeName): font,
            String(kCTForegroundColorAttributeName): color,
            String(kCTParagraphStyleAttributeName): style
            ])
    }
    var attributedString = NSAttributedString() {
        didSet {
            updateTextBounds()
        }
    }
    
    private(set) var stringBounds = CGRect(), imageBounds = CGRect(), width = 0.0.cf, ascent = 0.0.cf, descent = 0.0.cf, leading = 0.0.cf
    private mutating func updateTextBounds() {
        let aLine = CTLineCreateWithAttributedString(attributedString)
        width = CTLineGetTypographicBounds(aLine, &ascent, &descent, &leading).cf
        stringBounds = CGRect(x: 0, y: descent, width: width, height: ascent + descent)
        imageBounds = CTLineGetImageBounds(aLine, nil)
        line = aLine
    }
    
    var paddingSize: CGSize, isHorizontalCenter: Bool, isVerticalCenter: Bool, isCenterWithImageBounds: Bool
    func draw(in bounds: CGRect, in ctx: CGContext) {
        let x: CGFloat, y: CGFloat
        if isCenterWithImageBounds {
            if isHorizontalCenter {
                x = bounds.origin.x + (bounds.size.width - imageBounds.size.width)/2 - imageBounds.origin.x
            } else {
                x = bounds.origin.x + (alignment == .right ? bounds.width - stringBounds.width - paddingSize.width : paddingSize.width)
            }
            if isVerticalCenter {
                y = bounds.origin.y + (bounds.size.height - imageBounds.size.height)/2 - imageBounds.origin.y
            } else {
                y = bounds.origin.y + paddingSize.height
            }
        } else {
            if isHorizontalCenter {
                x = bounds.origin.x + (bounds.size.width - stringBounds.size.width)/2 + stringBounds.origin.x
            } else {
                x = bounds.origin.x + (alignment == .right ? bounds.width - stringBounds.width - paddingSize.width : paddingSize.width)
            }
            if isVerticalCenter {
                y = bounds.origin.y + (bounds.size.height - stringBounds.size.height)/2 + stringBounds.origin.y
            } else {
                y = bounds.origin.y + paddingSize.height
            }
        }
        ctx.textPosition = CGPoint(x: floor(x), y: floor(y))
        CTLineDraw(line, ctx)
    }
}
