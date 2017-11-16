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
//TextEditorの完成（タイムラインのスクロール設計と同等、モードレス・テキスト入力、TextEditorとLabelを統合）

import Foundation
import QuartzCore

protocol TextInputDelegate: class {
    func invalidateCharacterCoordinates()
    func discardMarkedText()
    func handleEvent(_ event: KeyInputEvent)
}
protocol TextInput {
//    var textManager: TextManager { get }
}
final class TextManager {
    
}

final class Text: NSObject, NSCoding {
    let string: String
    
    init(string: String = "") {
        self.string = string
        super.init()
    }
    
    static let stringKey = "0"
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
    let borderColor = Color.speechBorder, fillColor = Color.speechFill
    func draw(bounds: CGRect, in ctx: CGContext) {
        let attString = NSAttributedString(string: string, attributes: [
            String(kCTFontAttributeName): Font.speech.ctFont,
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
        ctx.setStrokeColor(borderColor.cgColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.setTextDrawingMode(.fill)
        ctx.setFillColor(fillColor.cgColor)
        CTFrameDraw(ctFrame, ctx)
        ctx.restoreGState()
    }
}

protocol TextEditorDelegate: class {
    func changeText(textEditor: TextEditor, string: String, oldString: String, type: Action.SendType)
}
final class TextEditor: LayerRespondable, TextInput {
    static let name = Localization(english: "Text Editor", japanese: "テキストエディタ")
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    var undoManager: UndoManager?
    
    weak var delegate: TextEditorDelegate?
    weak var textInputDelegate: TextInputDelegate?

    var backingStore = NSMutableAttributedString()
    var defaultAttributes = NSAttributedString.attributes(Font(size: 11), color: .font)
    var markedAttributes = NSAttributedString.attributes(Font(size: 11), color: .gray)

    var markedRange = NSRange(location: 0, length: 0) {
        didSet{
            updateTextLine()
        }
    }
    var selectedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            updateTextLine()
        }
    }

    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(backgroundColor: Color.background)
    
    var textLine: TextLine {
        didSet {
            layer.setNeedsDisplay()
        }
    }
    
    init(frame: CGRect = CGRect()) {
        self.textLine = TextLine()
        
        drawLayer.drawBlock = { [unowned self] ctx in
            self.draw(in: ctx)
        }
        layer.frame = frame
        
        self.backingStore = NSMutableAttributedString(string: "", attributes: defaultAttributes)
    }
    
    func word(for point: CGPoint) -> String {
        let characterIndex = self.characterIndex(for: point)
        var range = NSRange()
        if characterIndex >= selectedRange.location && characterIndex < NSMaxRange(selectedRange) {
            range = selectedRange
        } else {
            let string = backingStore.string as NSString
            let allRange = NSRange(location: 0, length: string.length)
            string.enumerateSubstrings(in: allRange, options: .byWords) { substring, substringRange, enclosingRange, stop in
                if characterIndex >= substringRange.location && characterIndex < NSMaxRange(substringRange) {
                    range = substringRange
                    stop.pointee = true
                }
            }
        }
        return backingStore.attributedSubstring(from: range).string
    }
    
    func updateTextLine() {
        textLine.attributedString = backingStore
    }
    func draw(in ctx: CGContext) {
        textLine.draw(in: bounds, in: ctx)
    }

    var cursor = Cursor.iBeam
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            textLine.frameWidth = layer.frame.width
        }
    }
    
    var string: String {
        get {
            return backingStore.string
        } set {
            backingStore.replaceCharacters(in: NSRange(location: 0, length: backingStore.length), with: newValue)
            backingStore.setAttributes(defaultAttributes, range: NSRange(location: 0, length: (newValue as NSString).length))
            unmarkText()
            
            self.selectedRange = NSRange(location: (newValue as NSString).length, length: 0)
            textInputDelegate?.invalidateCharacterCoordinates()
            
            updateTextLine()
        }
    }

    func delete(with event: KeyInputEvent) {
        deleteBackward()
    }
    
    func copy(with event: KeyInputEvent) -> CopyObject {
        if let backingStore = backingStore.copy() as? NSAttributedString {
            return CopyObject(objects: [backingStore.string])
        } else {
            return CopyObject()
        }
    }
    func paste(_ copyObject: CopyObject, with event: KeyInputEvent) {
        for object in copyObject.objects {
            if let string = object as? String {
                let oldString = string
                delegate?.changeText(textEditor: self, string: string, oldString: oldString, type: .begin)
                self.string = string
                delegate?.changeText(textEditor: self, string: string, oldString: oldString, type: .end)
            }
        }
    }
    
    private let timer = LockTimer()
    private var oldText = ""
    func keyInput(with event: KeyInputEvent) {
        timer.begin(
            endTimeLength: 1,
            beginHandler: { [unowned self] in
                self.oldText = self.string
                self.delegate?.changeText(textEditor: self, string: self.string, oldString: self.oldText, type: .begin)
            }, endHandler: { [unowned self] in
                self.delegate?.changeText(textEditor: self, string: self.string, oldString: self.oldText, type: .end)
            }
        )
        
        textInputDelegate?.handleEvent(event)
    }
    
    func click(with event: DragEvent) {
        let word = self.word(for: point(from: event))
        if word == "=" {
        }
    }
    
    func lookUp(with event: TapEvent) -> Referenceable {
        return word(for: point(from: event))
    }
    
    func insertNewline() {
        insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    func insertTab() {
        insertText("\t", replacementRange: NSRange(location: NSNotFound, length: 0))
    }
    func deleteBackward() {
        var deleteRange = selectedRange
        if deleteRange.length == 0 {
            if deleteRange.location == 0 {
                return
            } else {
                deleteRange.location -= 1
                deleteRange.length = 1
                deleteRange = (backingStore.string as NSString).rangeOfComposedCharacterSequences(for: deleteRange)
            }
        }
        deleteCharacters(in: deleteRange)
    }
    func deleteForward() {
        var deleteRange = selectedRange
        if deleteRange.length == 0 {
            if deleteRange.location == backingStore.length {
                return
            } else {
                deleteRange.length = 1
                deleteRange = (backingStore.string as NSString).rangeOfComposedCharacterSequences(for: deleteRange)
            }
        }
        deleteCharacters(in: deleteRange)
    }
    func moveLeft() {
        if selectedRange.length > 0 {
            selectedRange.length = 0
        } else if selectedRange.location > 0 {
            selectedRange.location -= 1
        }
    }
    func moveRight() {
        if selectedRange.length > 0 {
            selectedRange = NSRange(location: NSMaxRange(selectedRange), length: 0)
        } else if selectedRange.location > 0 {
            selectedRange.location += 1
        }
    }

    func deleteCharacters(in range: NSRange) {
        if NSLocationInRange(NSMaxRange(range), markedRange) {
            self.markedRange = NSRange(location: range.location, length: markedRange.length - (NSMaxRange(range) - markedRange.location))
        } else {
            markedRange.location -= range.length
        }
        if markedRange.length == 0 {
            unmarkText()
        }
        backingStore.deleteCharacters(in: range)
        self.selectedRange = NSRange(location: range.location, length: 0)
        textInputDelegate?.invalidateCharacterCoordinates()
        
        updateTextLine()
    }
    
    var hasMarkedText: Bool {
        return markedRange.location != NSNotFound
    }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let aReplacementRange = markedRange.location != NSNotFound ? markedRange : selectedRange
        if let attString = string as? NSAttributedString {
            if attString.length == 0 {
                backingStore.deleteCharacters(in: aReplacementRange)
                unmarkText()
            } else {
                self.markedRange = NSRange(location: aReplacementRange.location, length: attString.length)
                backingStore.replaceCharacters(in: aReplacementRange, with: attString)
                backingStore.addAttributes(markedAttributes, range: markedRange)
            }
        } else if let string = string as? String {
            if (string as NSString).length == 0 {
                backingStore.deleteCharacters(in: aReplacementRange)
                unmarkText()
            } else {
                self.markedRange = NSRange(location: aReplacementRange.location, length: (string as NSString).length)
                backingStore.replaceCharacters(in: aReplacementRange, with: string)
                backingStore.addAttributes(markedAttributes, range: markedRange)
            }
        }
        
        self.selectedRange = NSRange(location: aReplacementRange.location + selectedRange.location, length: selectedRange.length)
        textInputDelegate?.invalidateCharacterCoordinates()
        
        updateTextLine()
    }
    func unmarkText() {
        markedRange = NSRange(location: NSNotFound, length: 0)
        textInputDelegate?.discardMarkedText()
    }
    
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = range
        return backingStore.attributedSubstring(from: range)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        let replaceRange: NSRange
        if replacementRange.location != NSNotFound {
            replaceRange = replacementRange
        } else {
            replaceRange = markedRange.location != NSNotFound ? markedRange : selectedRange
        }
        
        if let attString = string as? NSAttributedString {
            backingStore.replaceCharacters(in: replaceRange, with: attString)
            backingStore.setAttributes(defaultAttributes, range: NSRange(location: replaceRange.location, length: attString.length))
        } else if let string = string as? String {
            backingStore.replaceCharacters(in: replaceRange, with: string)
            backingStore.setAttributes(defaultAttributes, range: NSRange(location: replaceRange.location, length: (string as NSString).length))
        }
        
        self.selectedRange = NSRange(location: backingStore.length, length: 0)
        unmarkText()
        textInputDelegate?.invalidateCharacterCoordinates()

        updateTextLine()
    }

    var attributedString: NSAttributedString {
        return backingStore
    }
    
    func characterIndex(for point: CGPoint) -> Int {
        if let textFrame = textLine.textFrame {
            return textFrame.characterIndex(for: point)
        } else if let textLine = textLine.line {
            return textLine.characterIndex(for: point)
        } else {
            fatalError()
        }
    }
    func characterOffset(for point: CGPoint) -> CGFloat {
        let i = characterIndex(for: point)
        if let textFrame = textLine.textFrame {
            return textFrame.characterOffset(at: i)
        } else if let line = textLine.line {
            return line.characterOffset(at: i)
        } else {
            fatalError()
        }
    }
    func baselineDelta(at i: Int) -> CGFloat {
        if let textFrame = textLine.textFrame {
            return textFrame.baselineDelta(at: i)
        } else if let textLine = textLine.line {
            return textLine.baselineDelta(at: i)
        } else {
            fatalError()
        }
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> CGRect {
        if let textFrame = textLine.textFrame {
            return textFrame.typographicBounds(for: range)
        } else if let textLine = textLine.line {
            return textLine.typographicBounds(for: range)
        } else {
            fatalError()
        }
    }
}

final class Label: LayerRespondable, Localizable {
    static let name = Localization(english: "Label", japanese: "ラベル")
    var instanceDescription: Localization
    var valueDescription: Localization {
        return text
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
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
    
    var defaultBorderColor: CGColor? {
        return layer.backgroundColor
    }
    
    var text = Localization() {
        didSet {
            textLine.string = text.string(with: locale)
        }
    }
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
    
    init(
        frame: CGRect = CGRect(), text: Localization, textLine: TextLine = TextLine(),
        backgroundColor: Color = .background, isSizeToFit: Bool = false, description: Localization = Localization()
    ) {
        self.instanceDescription = description
        self.drawLayer = DrawLayer(backgroundColor: backgroundColor)
        self.text = text
        self.textLine = textLine
        self.isSizeToFit = isSizeToFit
        drawLayer.drawBlock = { [unowned self] ctx in
            self.textLine.draw(in: self.bounds, in: ctx)
        }
        drawLayer.frame = frame
        highlight.layer.frame = bounds.inset(by: 0.5)
        drawLayer.addSublayer(highlight.layer)
    }
    convenience init(
        frame: CGRect = CGRect(), string: String, font: Font = .small, color: Color = .font,
        backgroundColor: Color = .background, paddingWidth: CGFloat = 0,
        isSizeToFit: Bool = true, description: Localization = Localization()
    ) {
        let text = Localization(string)
        let textLine = TextLine(string: text.currentString, font: font, color: color, paddingWidth: paddingWidth, frameWidth: frame.width == 0 ? nil : frame.width, isHorizontalCenter: true)
        let newFrame: CGRect
        if isSizeToFit {
            newFrame = CGRect(
                x: frame.origin.x, y: frame.origin.y,
                width: frame.width == 0 ? ceil(textLine.stringBounds.width + paddingWidth*2) : frame.width,
                height: frame.height == 0 ? textLine.stringBounds.height : frame.height
            )
        } else {
            newFrame = frame
        }
        self.init(frame: newFrame, text: text, textLine: textLine, backgroundColor: backgroundColor, isSizeToFit: isSizeToFit, description: description)
    }
    convenience init(
        frame: CGRect = CGRect(), text: Localization = Localization(), font: Font = .small, color: Color = .font,
        backgroundColor: Color = .background, paddingWidth: CGFloat = 0,
        isSizeToFit: Bool = true, description: Localization = Localization()
    ) {
        let textLine = TextLine(
            string: text.currentString, font: font, color: color,
            paddingWidth: paddingWidth, frameWidth: frame.width == 0 ? nil : frame.width, isHorizontalCenter: true
        )
        let newFrame: CGRect
        if isSizeToFit {
            newFrame = CGRect(
                x: frame.origin.x, y: frame.origin.y,
                width: frame.width == 0 ? ceil(textLine.stringBounds.width + paddingWidth*2) : frame.width,
                height: frame.height == 0 ? textLine.stringBounds.height : frame.height
            )
        } else {
            newFrame = frame
        }
        self.init(frame: newFrame, text: text, textLine: textLine, backgroundColor: backgroundColor, isSizeToFit: isSizeToFit, description: description)
    }
    func copy(with event: KeyInputEvent) -> CopyObject {
        return CopyObject(objects: [textLine.string])
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        } set {
            layer.frame = newValue
            highlight.layer.frame = bounds.inset(by: 0.5)
        }
    }
    var editBounds: CGRect {
        return textLine.stringBounds
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
    init(
        string: String = "", font: Font = .default, color: Color = .font,
        paddingWidth: CGFloat = Layout.basicPadding, paddingHeight: CGFloat = 0, alignment: CTTextAlignment = .natural,
        frameWidth: CGFloat? = nil, isHorizontalCenter: Bool = false, isVerticalCenter: Bool = true, isCenterWithImageBounds: Bool = false
    ) {
        self.frameWidth = frameWidth
        self.font = font
        self.color = color
        self.paddingSize = CGSize(width: paddingWidth, height: paddingHeight)
        self.alignment = alignment
        self.isHorizontalCenter = isHorizontalCenter
        self.isVerticalCenter = isVerticalCenter
        self.isCenterWithImageBounds = isCenterWithImageBounds
        updateAttributedString(string: string, font: font, color: color, alignment: alignment)
    }
    var line: CTLine?, textFrame: CTFrame?, frameWidth: CGFloat?
    
    var string: String {
        get {
            return attributedString.string
        } set {
            updateAttributedString(string: newValue, font: font, color: color, alignment: alignment)
        }
    }
    var font: Font {
        didSet {
            updateAttributedString(string: string, font: font, color: color, alignment: alignment)
        }
    }
    var color: Color {
        didSet {
            updateAttributedString(string: string, font: font, color: color, alignment: alignment)
        }
    }
    var alignment: CTTextAlignment
    private mutating func updateAttributedString(string: String, font: Font, color: Color, alignment: CTTextAlignment) {
        var alignment = alignment
        let settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &alignment)]
        let style = CTParagraphStyleCreate(settings, settings.count)
        attributedString = NSAttributedString(
            string: string,
            attributes: [
                String(kCTFontAttributeName): font.ctFont,
                String(kCTForegroundColorAttributeName): color.cgColor,
                String(kCTParagraphStyleAttributeName): style
            ]
        )
    }
    var attributedString = NSAttributedString() {
        didSet {
            updateTextLine()
        }
    }
    
    private(set) var stringBounds = CGRect(), imageBounds = CGRect(), width = 0.0.cf, ascent = 0.0.cf, descent = 0.0.cf, leading = 0.0.cf
    private mutating func updateTextLine() {
        guard let frameWidth = frameWidth else {
            self.line = CTLineCreateWithAttributedString(attributedString)
            let aLine = CTLineCreateWithAttributedString(attributedString)
            self.width = CTLineGetTypographicBounds(aLine, &ascent, &descent, &leading).cf
            self.stringBounds = CGRect(x: 0, y: descent, width: width, height: ascent + descent)
            self.imageBounds = CTLineGetImageBounds(aLine, nil)
            self.line = aLine
            return
        }
        let inWidth = frameWidth + (isHorizontalCenter ? 0 : -paddingSize.width*2)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRange(location: 0, length: attributedString.length), nil, CGSize(width: inWidth, height: CGFloat.infinity), nil
        )
        let path = CGPath(rect: CGRect(origin: CGPoint(), size: size), transform: nil)
        let textFrame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributedString.length), path, nil)
        self.textFrame = textFrame
        self.width = frameWidth
        self.stringBounds = CGRect(x: paddingSize.width, y: 0, width: inWidth, height: size.height)
        guard let lines = CTFrameGetLines(textFrame) as? [CTLine] else {
            imageBounds = CGRect()
            return
        }
        var origins = Array<CGPoint>(repeating: CGPoint(), count: lines.count)
        CTFrameGetLineOrigins(textFrame, CFRange(location: 0, length: attributedString.length), &origins)
        self.imageBounds = (0 ..< lines.count).reduce(CGRect()) {
            let line = lines[$1], origin = origins[$1]
            var imageBounds = CTLineGetImageBounds(line, nil)
            imageBounds.origin += origin
            return $0.unionNoEmpty(imageBounds)
        }
    }
    
    var paddingSize: CGSize, isHorizontalCenter: Bool, isVerticalCenter: Bool, isCenterWithImageBounds: Bool
    func draw(in bounds: CGRect, in ctx: CGContext) {
        let x: CGFloat, y: CGFloat
        if isCenterWithImageBounds {
            x = isHorizontalCenter ?
                bounds.origin.x + (bounds.size.width - imageBounds.size.width)/2 - imageBounds.origin.x :
                bounds.origin.x + (alignment == .right ? bounds.width - stringBounds.width - paddingSize.width : paddingSize.width)
            y = isVerticalCenter ?
                bounds.origin.y + (bounds.size.height - imageBounds.size.height)/2 - imageBounds.origin.y :
                bounds.origin.y + paddingSize.height
        } else {
            x = isHorizontalCenter ?
                bounds.origin.x + (bounds.size.width - stringBounds.size.width)/2 + stringBounds.origin.x :
                bounds.origin.x + (alignment == .right ? bounds.width - stringBounds.width - paddingSize.width : paddingSize.width)
            y = isVerticalCenter ?
                bounds.origin.y + (bounds.size.height - stringBounds.size.height)/2 + stringBounds.origin.y :
                bounds.origin.y + paddingSize.height
        }

        if let line = line {
            ctx.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, ctx)
        } else if let textFrame = textFrame {
            ctx.translateBy(x: paddingSize.width, y: bounds.height - stringBounds.height - paddingSize.height)
            CTFrameDraw(textFrame, ctx)
        }
    }
}

extension CTRun {
    func typographicBounds(for range: NSRange) -> CGRect {
        var ascent = 0.0.cf, descent = 0.0.cf, leading = 0.0.cf
        let width = CTRunGetTypographicBounds(self, CFRange(location: range.location, length: range.length), &ascent, &descent, &leading).cf
        return CGRect(x: 0, y: descent + leading, width: width, height: ascent + descent)
    }
}

extension CTLine {
    var runs: [CTRun] {
        return CTLineGetGlyphRuns(self) as? [CTRun] ?? []
    }
    func contains(at i: Int) -> Bool {
        let range = CTLineGetStringRange(self)
        return i >= range.location && i < range.location + range.length
    }
    func contains(for range: NSRange) -> Bool {
        let lineRange = CTLineGetStringRange(self)
        return !(range.location >= lineRange.location + lineRange.length || range.location + range.length <= lineRange.location)
    }
    var typographicBounds: CGRect {
        var ascent = 0.0.cf, descent = 0.0.cf, leading = 0.0.cf
        let width = CTLineGetTypographicBounds(self, &ascent, &descent, &leading).cf
        return CGRect(x: 0, y: descent + leading, width: width, height: ascent + descent)
    }
    func typographicBounds(for range: NSRange) -> CGRect {
        guard contains(for: range) else {
            return CGRect()
        }
        return self.runs.reduce(CGRect()) {
            var origin = CGPoint()
            CTRunGetPositions($1, CFRange(location: range.location, length: 1), &origin)
            let bounds = $1.typographicBounds(for: range)
            return $0.unionNoEmpty(CGRect(origin: origin + bounds.origin, size: bounds.size))
        }
    }
    func characterIndex(for point: CGPoint) -> Int {
        return CTLineGetStringIndexForPosition(self, point)
    }
    func characterOffset(at i: Int) -> CGFloat {
        var offset = 0.5.cf
        CTLineGetOffsetForStringIndex(self, i, &offset)
        return offset
    }
    func baselineDelta(at i: Int) -> CGFloat {
        var descent = 0.0.cf, leading = 0.0.cf
        _ = CTLineGetTypographicBounds(self, nil, &descent, &leading)
        return descent + leading
    }
}

extension CTFrame {
    var lines: [CTLine] {
        return CTFrameGetLines(self) as? [CTLine] ?? []
    }
    var origins: [CGPoint] {
        var origins = Array<CGPoint>(repeating: CGPoint(), count: lines.count)
        CTFrameGetLineOrigins(self, CTFrameGetStringRange(self), &origins)
        return origins
    }
    func characterIndex(for point: CGPoint) -> Int {
        let lines = self.lines, origins = self.origins
        guard !lines.isEmpty else {
            return 0
        }
        for (i, origin) in origins.enumerated() {
            if point.y >= origin.y {
                return CTLineGetStringIndexForPosition(lines[i], point - origin)
            }
        }
        return CTLineGetStringIndexForPosition(lines[lines.count - 1], point - origins[origins.count - 1])
    }
    func characterOffset(at i: Int) -> CGFloat {
        let lines = self.lines
        for line in lines {
            if line.contains(at: i) {
                return line.characterOffset(at: i)
            }
        }
        return 0.5
    }
    func typographicBounds(for range: NSRange) -> CGRect {
        let origins = self.origins
        return self.lines.enumerated().reduce(CGRect()) {
            let origin = origins[$1.offset]
            let bounds = $1.element.typographicBounds(for: range)
            return $0.unionNoEmpty(CGRect(origin: origin + bounds.origin, size: bounds.size))
        }
    }
    func baselineDelta(at i: Int) -> CGFloat {
        let lines = self.lines
        for line in lines {
            if line.contains(at: i) {
                return line.baselineDelta(at: i)
            }
        }
        return 0.0
    }
}

extension NSAttributedString {
    static func attributes(_ font: Font, color: Color) -> [String: Any] {
        return [String(kCTFontAttributeName): font.ctFont, String(kCTForegroundColorAttributeName): color.cgColor]
    }
}
