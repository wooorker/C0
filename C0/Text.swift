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

/*
 # Issue
 TextEditorの完成（タイムラインのスクロール設計と同等）
*/

import Foundation
import QuartzCore

protocol TextDelegate: class {
    func changeString(_ text: Text, string: String, oldString: String, type: Action.SendType)
    func didSetBounds(_ text: Text, bounds: CGRect, oldValue: CGRect)
    func didSetFrame(_ text: Text, frame: CGRect, oldValue: CGRect)
    func didSetTextFrame(_ text: Text, textFrame: TextFrame, oldValue: TextFrame)
    func updateDraw(_ text: Text)
}
final class Text: Respondable, Localizable {
    static let name = Localization(english: "Text", japanese: "テキスト")
    static var feature: Localization {
        return Localization(
            english: "Run: Click (Verb sentence only. Invalid if the execution name exists in the actions)",
            japanese: "実行: クリック (動詞文のみ。実行名がアクション内に存在する場合は無効)"
        )
    }
    var instanceDescription: Localization
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            CATransaction.disableAnimation {
                string = localization.string(with: locale)
                if isSizeToFit {
                    sizeToFit()
                }
            }
        }
    }
    var isSizeToFit = false
    var localization: Localization {
        didSet {
            string = localization.currentString
        }
    }
    
    weak var delegate: TextDelegate?
    
    var backingStore = NSMutableAttributedString() {
        didSet {
            self.textFrame = TextFrame(attributedString: backingStore)
        }
    }
    var defaultAttributes = NSAttributedString.attributesWith(font: .small, color: .font)
    var markedAttributes = NSAttributedString.attributesWith(font: .small, color: .gray)
    
    var markedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            if !NSEqualRanges(markedRange, oldValue) {
                delegate?.updateDraw(self)
            }
        }
    }
    var selectedRange = NSRange(location: NSNotFound, length: 0) {
        didSet{
            if !NSEqualRanges(selectedRange, oldValue) {
                delegate?.updateDraw(self)
            }
        }
    }
    
    var textFrame: TextFrame {
        didSet {
            if let firstLine = textFrame.lines.first, let lastLine = textFrame.lines.last {
                baselineDelta = -lastLine.origin.y - baseFont.descent
                height = firstLine.origin.y + baseFont.ascent
            } else {
                baselineDelta = 0
                height = 0
            }
            if useDidSetTextFrame && isSizeToFit {
                sizeToFit()
            }
            delegate?.didSetTextFrame(self, textFrame: textFrame, oldValue: oldValue)
        }
    }
    
    var isLocked = true
    
    var contentsScale = 1.0.cf
    var isIndication = false {
        didSet {
            delegate?.updateDraw(self)
        }
    }
    var baseFont: Font, baselineDelta: CGFloat, height: CGFloat, padding: CGFloat
    
    init(
        frame: CGRect = CGRect(),
        localization: Localization = Localization(),
        font: Font = .small, color: Color = .font, alignment: CTTextAlignment = .natural,
        padding: CGFloat = 1, isSizeToFit: Bool = true,
        description: Localization = Localization()
    ) {
        self.localization = localization
        self.padding = padding
        self.baseFont = font
        self.defaultAttributes = NSAttributedString.attributesWith(font: font, color: color, alignment: alignment)
        self.backingStore = NSMutableAttributedString(string: localization.currentString, attributes: defaultAttributes)
        if frame.width == 0 {
            self.textFrame = TextFrame(attributedString: backingStore)
        } else {
            self.textFrame = TextFrame(attributedString: backingStore, frameWidth: frame.width - padding * 2)
        }
        
        if let firstLine = textFrame.lines.first, let lastLine = textFrame.lines.last {
            baselineDelta = -lastLine.origin.y - baseFont.descent
            height = firstLine.origin.y + baseFont.ascent
        } else {
            baselineDelta = 0
            height = 0
        }
        
        self.isSizeToFit = isSizeToFit
        if isSizeToFit {
            self.frame = CGRect(
                x: frame.origin.x, y: frame.origin.y,
                width: frame.width == 0 ? ceil(textFrame.pathBounds.width) + padding * 2 : frame.width,
                height: frame.height == 0 ? ceil(height + baselineDelta) + padding * 2 : frame.height
            )
        } else {
            self.frame = frame
        }
        self.bounds = CGRect(origin: CGPoint(x: -padding, y: -padding), size: self.frame.size)
        self.instanceDescription = description
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
    
    func updateTextFrame() {
        textFrame.attributedString = backingStore
    }
    func draw(in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: padding, y: padding + baselineDelta)
        textFrame.draw(in: bounds, in: ctx)
        ctx.restoreGState()
        if isIndication {
            ctx.setStrokeColor(Color.indication.cgColor)
            ctx.setLineWidth(0.5)
            ctx.stroke(bounds.inset(by: 0.25))
        }
    }
    
    private var useDidSetBounds = true, useDidSetFrame = true, useDidSetTextFrame = true
    var bounds: CGRect {
        didSet {
            guard useDidSetBounds && bounds != oldValue else {
                return
            }
            useDidSetFrame = false
            frame.size = bounds.size
            useDidSetFrame = true
            if textFrame.frameWidth != nil {
                useDidSetTextFrame = false
                textFrame.frameWidth = frame.width - padding * 2
                useDidSetTextFrame = true
            }
            delegate?.didSetBounds(self, bounds: bounds, oldValue: oldValue)
        }
    }
    var frame: CGRect {
        didSet {
            guard useDidSetFrame && frame != oldValue else {
                return
            }
            useDidSetBounds = false
            bounds.size = frame.size
            useDidSetBounds = true
            if textFrame.frameWidth != nil {
                useDidSetTextFrame = false
                textFrame.frameWidth = frame.width - padding * 2
                useDidSetTextFrame = true
            }
            delegate?.didSetFrame(self, frame: frame, oldValue: oldValue)
        }
    }
    
    func sizeToFit() {
//        if let firstLine = textFrame.lines.first, let lastLine = textFrame.lines.last {
//            baselineDelta = -lastLine.origin.y - baseFont.descent
//            height = firstLine.origin.y + baseFont.ascent
//        } else {
//            baselineDelta = 0
//            height = 0
//        }
        self.frame = CGRect(origin: frame.origin, size: fitSize)
    }
    var fitSize: CGSize {
        return CGSize(
            width: (textFrame.frameWidth ?? ceil(textFrame.pathBounds.width)) + padding * 2,
            height: ceil(height + baselineDelta) + padding * 2
        )
    }
    
    var string: String {
        get {
            return backingStore.string
        }
        set {
            backingStore.replaceCharacters(in: NSRange(location: 0, length: backingStore.length), with: newValue)
            backingStore.setAttributes(defaultAttributes, range: NSRange(location: 0, length: backingStore.length))
            unmarkText()
            
            self.selectedRange = NSRange(location: (newValue as NSString).length, length: 0)
            TextInputContext.invalidateCharacterCoordinates()
            
            updateTextFrame()
        }
    }
    
    func delete(with event: KeyInputEvent) {
        guard !isLocked else {
            parent?.delete(with: event)
            return
        }
        deleteBackward()
    }
    
    func copy(with event: KeyInputEvent) -> CopiedObject {
        if let backingStore = backingStore.copy() as? NSAttributedString {
            return CopiedObject(objects: [backingStore.string])
        } else {
            return CopiedObject()
        }
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        guard !isLocked else {
            parent?.paste(copiedObject, with: event)
            return
        }
        for object in copiedObject.objects {
            if let string = object as? String {
                let oldString = string
                delegate?.changeString(self, string: string, oldString: oldString, type: .begin)
                self.string = string
                delegate?.changeString(self, string: string, oldString: oldString, type: .end)
            }
        }
    }
    
    func moveCursor(with event: MoveEvent) {
        selectedRange = NSRange(location: editCharacterIndex(for: point(from: event)), length: 0)
    }
    
    private let timer = LockTimer()
    private var oldText = ""
    func keyInput(with event: KeyInputEvent) {
        timer.begin(
            endTimeLength: 1,
            beginHandler: { [unowned self] in
                self.oldText = self.string
                self.delegate?.changeString(self, string: self.string, oldString: self.oldText, type: .begin)
            },
            endHandler: { [unowned self] in
                self.delegate?.changeString(self, string: self.string, oldString: self.oldText, type: .end)
            }
        )
    }
    
    func click(with event: DragEvent) {
        let word = self.word(for: point(from: event))
        if word == "=" {
        } else {
            parent?.click(with: event)
        }
    }
    
    func select(with event: DragEvent) {
    }
    func deselect(with event: DragEvent) {
    }
    func deselectAll(with event: KeyInputEvent) {
    }
    func selectAll(with event: KeyInputEvent) {
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
        TextInputContext.invalidateCharacterCoordinates()
        
        updateTextFrame()
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
        TextInputContext.invalidateCharacterCoordinates()
        
        updateTextFrame()
    }
    func unmarkText() {
        if markedRange.location != NSNotFound {
            markedRange = NSRange(location: NSNotFound, length: 0)
            TextInputContext.discardMarkedText()
        }
    }
    
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        actualRange?.pointee = range
        return backingStore.attributedSubstring(from: range)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        let replaceRange = replacementRange.location != NSNotFound ?
            replacementRange : (markedRange.location != NSNotFound ? markedRange : selectedRange)
        
        if let attString = string as? NSAttributedString {
            let range = NSRange(location: replaceRange.location, length: attString.length)
            backingStore.replaceCharacters(in: replaceRange, with: attString)
            backingStore.setAttributes(defaultAttributes, range: range)
            selectedRange = NSRange(location: selectedRange.location + range.length, length: 0)
        } else if let string = string as? String {
            let range = NSRange(location: replaceRange.location, length: (string as NSString).length)
            backingStore.replaceCharacters(in: replaceRange, with: string)
            backingStore.setAttributes(defaultAttributes, range: range)
            selectedRange = NSRange(location: selectedRange.location + range.length, length: 0)
        }
        
        unmarkText()
        TextInputContext.invalidateCharacterCoordinates()
        
        updateTextFrame()
    }
    
    var attributedString: NSAttributedString {
        return backingStore
    }
    
    func editCharacterIndex(for p: CGPoint) -> Int {
        let index = characterIndex(for: p)
        let offset = characterFraction(for: p)
        return offset < 0.5 ? index : index + 1
    }
    func characterIndex(for point: CGPoint) -> Int {
        return textFrame.characterIndex(for: point)
    }
    func characterFraction(for point: CGPoint) -> CGFloat {
        return textFrame.characterFraction(for: point)
    }
    func characterOffset(for point: CGPoint) -> CGFloat {
        let i = characterIndex(for: point)
        return textFrame.characterOffset(at: i)
    }
    func baselineDelta(at i: Int) -> CGFloat {
        return textFrame.baselineDelta(at: i)
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> CGRect {
        return textFrame.typographicBounds(for: range)
    }
}

typealias Label = TextEditor
final class TextEditor: LayerRespondable, TextDelegate {
    static let name = Localization(english: "Text Editor", japanese: "テキストエディタ")
    static var feature: Localization {
        return Text.feature
    }
    var instanceDescription: Localization
    var valueDescription: Localization {
        return text.localization
    }
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var text: Text
    
    func didSetTextFrame(_ text: Text, textFrame: TextFrame, oldValue: TextFrame) {
        layer.setNeedsDisplay()
    }
    func didSetBounds(_ text: Text, bounds: CGRect, oldValue: CGRect) {
        CATransaction.disableAnimation {
            let oldValue = layer.frame
            layer.bounds = bounds
            if text.textFrame.alignment == .right {
                layer.frame.origin.x = oldValue.maxX - ceil(text.textFrame.pathBounds.width) - text.padding * 2
            }
        }
    }
    func didSetFrame(_ text: Text, frame: CGRect, oldValue: CGRect) {
        CATransaction.disableAnimation {
            let oldValue = layer.frame
            layer.frame.size = frame.size
            if text.textFrame.alignment == .right {
                layer.frame.origin.x = oldValue.maxX - ceil(text.textFrame.pathBounds.width) - text.padding * 2
            }
            layer.frame.origin.y = oldValue.maxY - frame.height
        }
    }
    func changeString(_ text: Text, string: String, oldString: String, type: Action.SendType) {
        layer.setNeedsDisplay()
    }
    func updateDraw(_ text: Text) {
        layer.setNeedsDisplay()
    }
    
    var defaultBorderColor: CGColor? {
        return nil
    }
    var layer: CALayer {
        return drawLayer
    }
    let drawLayer = DrawLayer(borderColor: nil)
    
    init(
        frame: CGRect = CGRect(),
        text localization: Localization = Localization(),
        font: Font = .small, color: Color = .locked, alignment: CTTextAlignment = .natural,
        padding: CGFloat = 1, isSizeToFit: Bool = true,
        description: Localization = Localization()
    ) {
        self.text = Text(
            frame: CGRect(origin: CGPoint(), size: frame.size),
            localization: localization,
            font: font, color: color, alignment: alignment,
            padding: padding, isSizeToFit: isSizeToFit,
            description: description
        )
        self.instanceDescription = description
        self.children = [text]
        update(withChildren: children, oldChildren: [])
        
        drawLayer.drawBlock = { [unowned self] ctx in
            self.text.draw(in: ctx)
        }
        layer.borderWidth = 0
        layer.bounds = text.bounds
        layer.frame = CGRect(origin: frame.origin, size: text.frame.size)
        text.delegate = self
    }
    
    var bounds: CGRect {
        get {
            return layer.bounds
        }
        set {
            CATransaction.disableAnimation {
                text.bounds = newValue
                layer.bounds = newValue
            }
        }
    }
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            CATransaction.disableAnimation {
                text.frame = CGRect(origin: CGPoint(), size: newValue.size)
                layer.frame = newValue
            }
        }
    }
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        }
        set {
            text.contentsScale = newValue
            layer.contentsScale = newValue
        }
    }
}

struct TextFrame {
    var attributedString = NSAttributedString() {
        didSet {
            self.lines = TextFrame.lineWith(attributedString: attributedString, frameWidth: frameWidth)
        }
    }
    var string: String {
        get {
            return attributedString.string
        }
        set(string) {
            self.attributedString = .with(string: string, font: font, color: color, alignment: alignment)
        }
    }
    var font: Font? {
        get {
            return attributedString.font
        }
        set(font) {
            self.attributedString = attributedString.with(font)
        }
    }
    var color: Color? {
        get {
            return attributedString.color
        }
        set(color) {
            self.attributedString = attributedString.with(color)
        }
    }
    var alignment: CTTextAlignment? {
        get {
            return attributedString.alignment
        }
        set(alignment) {
            self.attributedString = attributedString.with(alignment)
        }
    }
    private(set) var typographicBounds = CGRect()
    var pathBounds: CGRect {
        return typographicBounds
    }
    
    var frameWidth: CGFloat? {
        didSet {
            self.lines = TextFrame.lineWith(attributedString: attributedString, frameWidth: frameWidth)
        }
    }
    
    init (attributedString: NSAttributedString, frameWidth: CGFloat? = nil) {
        self.attributedString = attributedString
        self.frameWidth = frameWidth
        self.lines = TextFrame.lineWith(attributedString: attributedString, frameWidth: frameWidth)
        self.typographicBounds = TextFrame.typographicBounds(with: lines)
    }
    init(
        string: String = "", font: Font = .default, color: Color = .font, alignment: CTTextAlignment = .natural,
        frameWidth: CGFloat? = nil
    ) {
        self.init(
            attributedString: .with(string: string, font: font, color: color, alignment: alignment),
            frameWidth: frameWidth
        )
    }
    
    var lines = [TextLine]() {
        didSet {
            self.typographicBounds = TextFrame.typographicBounds(with: lines)
        }
    }
    private static func lineWith(attributedString: NSAttributedString, frameWidth: CGFloat?) -> [TextLine] {
        let width = Double(frameWidth ?? CGFloat.infinity)
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let length = attributedString.length
        var range = CFRange(), h = 0.0.cf, ls = [(ctLine: CTLine, ascent: CGFloat, descent: CGFloat, leading: CGFloat)]()
        while range.maxLength < length {
            range.length = CTTypesetterSuggestLineBreak(typesetter, range.location, width)
            let ctLine = CTTypesetterCreateLine(typesetter, range)
            var ascent = 0.0.cf, descent = 0.0.cf, leading =  0.0.cf
            _ = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading)
            ls.append((ctLine, ascent, descent, leading))
            range = CFRange(location: range.maxLength, length: 0)
            h += ascent + descent + leading
        }
        var origin = CGPoint()
        return ls.reversed().map {
            origin.y += $0.descent + $0.leading
            let result = TextLine(ctLine: $0.ctLine, origin: origin)
            origin.y += $0.ascent
            return result
        }.reversed()
    }
    
    func line(for point: CGPoint) -> TextLine? {
        guard let lastLine = lines.last else {
            return nil
        }
        for line in lines {
            let bounds = line.typographicBounds
            let tb = CGRect(origin: line.origin + bounds.origin, size: bounds.size)
            if point.y >= tb.minY {
                return line
            }
        }
        return lastLine
    }

    func characterIndex(for point: CGPoint) -> Int {
        guard !lines.isEmpty else {
            return 0
        }
        for line in lines {
            let bounds = line.typographicBounds
            let tb = CGRect(origin: line.origin + bounds.origin, size: bounds.size)
            if point.y >= tb.minY {
                return line.characterIndex(for: point - tb.origin)
            }
        }
        return attributedString.length - 1
    }
    func characterFraction(for point: CGPoint) -> CGFloat {
        guard let line = self.line(for: point) else {
            return 0.0
        }
        return line.characterFraction(for: point - line.origin)
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
    var imageBounds: CGRect {
        let lineAndOrigins = self.lines
        return lineAndOrigins.reduce(CGRect()) {
            var imageBounds = $1.imageBounds
            imageBounds.origin += $1.origin
            return $0.unionNoEmpty(imageBounds)
        }
    }
    static func typographicBounds(with lines: [TextLine]) -> CGRect {
        return lines.reduce(CGRect()) {
            let bounds = $1.typographicBounds
            return $0.unionNoEmpty(CGRect(origin: $1.origin + bounds.origin, size: bounds.size))
        }
    }
    func typographicBounds(for range: NSRange) -> CGRect {
        return lines.reduce(CGRect()) {
            let bounds = $1.typographicBounds(for: range)
            return $0.unionNoEmpty(CGRect(origin: $1.origin + bounds.origin, size: bounds.size))
        }
    }
    func baselineDelta(at i: Int) -> CGFloat {
        for line in lines {
            if line.contains(at: i) {
                return line.baselineDelta(at: i)
            }
        }
        return 0.0
    }
    
    func draw(in bounds: CGRect, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: bounds.origin.x, y: bounds.origin.y)
        lines.forEach { $0.draw(in: ctx) }
        ctx.restoreGState()
    }
    func drawWithCenterOfImageBounds(in bounds: CGRect, in ctx: CGContext) {
        let imageBounds = self.imageBounds
        ctx.saveGState()
        ctx.translateBy(x: bounds.midX - imageBounds.midX, y: bounds.midY - imageBounds.midY)
        lines.forEach { $0.draw(in: ctx) }
        ctx.restoreGState()
    }
}

struct TextLine {
    let ctLine: CTLine
    let origin: CGPoint
    
    func contains(at i: Int) -> Bool {
        let range = CTLineGetStringRange(ctLine)
        return i >= range.location && i < range.location + range.length
    }
    func contains(for range: NSRange) -> Bool {
        let lineRange = CTLineGetStringRange(ctLine)
        return !(range.location >= lineRange.location + lineRange.length || range.location + range.length <= lineRange.location)
    }
    var typographicBounds: CGRect {
        var ascent = 0.0.cf, descent = 0.0.cf, leading = 0.0.cf
        let width = CTLineGetTypographicBounds(ctLine, &ascent, &descent, &leading).cf + CTLineGetTrailingWhitespaceWidth(ctLine).cf
        return CGRect(x: 0, y: -descent - leading, width: width, height: ascent + descent + leading)
    }
    func typographicBounds(for range: NSRange) -> CGRect {
        guard contains(for: range) else {
            return CGRect()
        }
        return ctLine.runs.reduce(CGRect()) {
            var origin = CGPoint()
            CTRunGetPositions($1, CFRange(location: range.location, length: 1), &origin)
            let bounds = $1.typographicBounds(for: range)
            return $0.unionNoEmpty(CGRect(origin: origin + bounds.origin, size: bounds.size))
        }
    }
    func characterIndex(for point: CGPoint) -> Int {
        return CTLineGetStringIndexForPosition(ctLine, point)
    }
    func characterFraction(for point: CGPoint) -> CGFloat {
        let i = characterIndex(for: point)
        if i < CTLineGetStringRange(ctLine).maxLength {
            let x = characterOffset(at: i)
            let nextX = characterOffset(at: i + 1)
            return (point.x - x) / (nextX - x)
        }
        return 0.0
    }
    func characterOffset(at i: Int) -> CGFloat {
        var offset = 0.5.cf
        CTLineGetOffsetForStringIndex(ctLine, i, &offset)
        return offset
    }
    func baselineDelta(at i: Int) -> CGFloat {
        var descent = 0.0.cf, leading = 0.0.cf
        _ = CTLineGetTypographicBounds(ctLine, nil, &descent, &leading)
        return descent + leading
    }
    var imageBounds: CGRect {
        return CTLineGetImageBounds(ctLine, nil)
    }
    
    func draw(in ctx: CGContext) {
        ctx.textPosition = origin
        CTLineDraw(ctLine, ctx)
    }
}

extension CFRange {
    var maxLength: Int {
        return location + length
    }
}

extension CTRun {
    func typographicBounds(for range: NSRange) -> CGRect {
        var ascent = 0.0.cf, descent = 0.0.cf, leading = 0.0.cf
        let range = CFRange(location: range.location, length: range.length)
        let width = CTRunGetTypographicBounds(self, range, &ascent, &descent, &leading)
        return CGRect(x: 0, y: -descent, width: width.cf, height: ascent + descent)
    }
}

extension CTLine {
    var runs: [CTRun] {
        return CTLineGetGlyphRuns(self) as? [CTRun] ?? []
    }
}

extension NSAttributedString {
    static func with(string: String, font: Font?, color: Color?, alignment: CTTextAlignment? = nil) -> NSAttributedString {
        var attributes = [String: Any]()
        if let font = font {
            attributes[String(kCTFontAttributeName)] = font.ctFont
        }
        if let color = color {
            attributes[String(kCTForegroundColorAttributeName)] = color.cgColor
        }
        if var alignment = alignment {
            let settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &alignment)]
            let style = CTParagraphStyleCreate(settings, settings.count)
            attributes[String(kCTParagraphStyleAttributeName)] = style
        }
        return NSAttributedString(string: string, attributes: attributes)
    }
    var font: Font? {
        if length == 0 {
            return nil
        } else if let obj = attribute(String(kCTFontAttributeName), at: 0, effectiveRange: nil) {
            return Font(obj as! CTFont)
        } else {
            return nil
        }
    }
    func with(_ font: Font?) -> NSAttributedString {
        guard length > 0 else {
            return NSAttributedString()
        }
        let attString = NSMutableAttributedString(attributedString: self)
        attString.removeAttribute(String(kCTFontAttributeName), range: NSRange(location: 0, length: length))
        if let font = font {
            attString.addAttribute(String(kCTFontAttributeName), value: font.ctFont, range: NSRange(location: 0, length: length))
        }
        return attString
    }
    var color: Color? {
        if length == 0 {
            return nil
        } else if let obj = attribute(String(kCTForegroundColorAttributeName), at: 0, effectiveRange: nil) {
            return Color(obj as! CGColor)
        } else {
            return nil
        }
    }
    func with(_ color: Color?) -> NSAttributedString {
        guard length > 0 else {
            return NSAttributedString()
        }
        let attString = NSMutableAttributedString(attributedString: self)
        attString.removeAttribute(String(kCTForegroundColorAttributeName), range: NSRange(location: 0, length: length))
        if let color = color {
            attString.addAttribute(String(kCTForegroundColorAttributeName), value: color.cgColor, range: NSRange(location: 0, length: length))
        }
        return attString
    }
    var alignment: CTTextAlignment? {
        if length == 0 {
            return nil
        } else if let obj = attribute(String(kCTParagraphStyleAttributeName), at: 0, effectiveRange: nil) {
            var alignment = CTTextAlignment.natural
            CTParagraphStyleGetValueForSpecifier(
                obj as! CTParagraphStyle, CTParagraphStyleSpecifier.alignment, MemoryLayout<CTTextAlignment>.size, &alignment
            )
            return alignment
        } else {
            return nil
        }
    }
    func with(_ alignment: CTTextAlignment?) -> NSAttributedString {
        guard length > 0 else {
            return NSAttributedString()
        }
        let attString = NSMutableAttributedString(attributedString: self)
        attString.removeAttribute(String(kCTParagraphStyleAttributeName), range: NSRange(location: 0, length: length))
        if var alignment = alignment {
            let settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &alignment)]
            let style = CTParagraphStyleCreate(settings, settings.count)
            attString.addAttribute(String(kCTParagraphStyleAttributeName), value: style, range: NSRange(location: 0, length: length))
        }
        return attString
    }
    static func attributesWith(font: Font, color: Color, alignment: CTTextAlignment = .natural) -> [String: Any] {
        var alignment = alignment
        let settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: &alignment)]
        let style = CTParagraphStyleCreate(settings, settings.count)
        return [
            String(kCTFontAttributeName): font.ctFont,
            String(kCTForegroundColorAttributeName): color.cgColor,
            String(kCTParagraphStyleAttributeName): style
        ]
    }
}
