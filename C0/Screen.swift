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

final class Screen: NSView, NSTextInputClient, StringViewDelegate {
    static var defaultActionNode: ActionNode {
        return ActionNode(children: [
            ActionNode(actions: [
                Action(name: "Undo".localized, quasimode: [.command], key: .z, keyInput: { $0.undo() }),
                Action(name: "Redo".localized, quasimode: [.shift, .command], key: .z, keyInput: { $0.redo() })
                ]),
            ActionNode(actions: [
                Action(name: "Cut".localized, quasimode: [.command], key: .x, keyInput: { $0.cut() }),
                Action(name: "Copy".localized, quasimode: [.command], key: .c, keyInput: { $0.copy() }),
                Action(name: "Paste".localized, description:
                    "If cell, replace line of cell with same ID with line of paste cell".localized,
                       quasimode: [.command], key: .v, keyInput: { $0.paste() }),
                Action(name: "Delete".localized, description:
                    "If slider, Initialize value, if canvas, delete line preferentially".localized,
                    key: .delete, keyInput: { $0.delete() })
                ]),
            ActionNode(actions: [
                Action(name: "Move to Previous Keyframe".localized, key: .z, keyInput: { $0.moveToPrevious() }),
                Action(name: "Move to Next Keyframe".localized, key: .x, keyInput: { $0.moveToNext() }),
                Action(name: "Play".localized, key: .space, keyInput: { $0.play() })
                ]),
            ActionNode(actions: [
                Action(name: "Add Cell with Lines".localized, description:
                    "If editing cell by click, add cells by connecting to that cell (Other than draw first line in line with arrow line, direction and order of line is free)".localized,
                       key: .a, keyInput: { $0.addCellWithLines() }),
                Action(name: "Add & Clip Cell with Lines".localized, description:
                    "Clip created cell into  indicated cell (If cell to clip is selected, include selected cells in other groups)".localized,
                    key: .r, keyInput: { $0.addAndClipCellWithLines() }),
                Action(name: "Lasso Select".localized, description:
                    "Select line or cell surrounded by last drawn line".localized,
                       key: .s, keyInput: { $0.lassoSelect() } ),
                Action(name: "Lasso Delete".localized, description:
                    "Delete line or cell or plane surrounded by last drawn line".localized,
                       key: .d, keyInput: { $0.lassoDelete() }),
                Action(name: "Lasso Delete Selection".localized, description:
                    "Delete selection of line or cell surrounded by last drawn line".localized,
                    key: .f, keyInput: { $0.lassoDeleteSelect() }),
                Action(name: "Clip Cell in Selection".localized, description:
                    "Clip indicated cell into selection, if no selection, unclip indicated cell".localized,
                       key: .g, keyInput: { $0.clipCellInSelection() }),
                ]),
            ActionNode(actions: [
                Action(name: "Paste cell without connect".localized, description:
                    "Completely replicate and paste copied cells".localized,
                       quasimode: [.shift], key: .v, keyInput: { $0.pasteCell() })
                ]),
            ActionNode(actions: [
                Action(name: "Copy & Bind Material".localized, description:
                    "After copying material of indicated cell, bind it to material view".localized,
                       key: .c, keyInput: { $0.copyAndBindMaterial() }),
                Action(name: "Paste Material".localized, description:
                    "Paste material into indicated cell".localized,
                       key: .v, keyInput: { $0.pasteMaterial() }),
                Action(name: "Split Color".localized, description:
                    "Distribute ID of color of indicated cell newly (maintain ID relationship within same selection)".localized,
                       key: .b, keyInput: { $0.splitColor() }),
                Action(name: "Split Other Than Color".localized, description:
                    "Distribute ID of material of indicated cell without changing color ID (Maintain ID relationship within same selection)".localized,
                       key: .n, keyInput: { $0.splitOtherThanColor() })
                ]),
            ActionNode(actions: [
                Action(name: "Change to Rough".localized, description:
                    "If selecting line, move only that line to rough layer".localized,
                       key: .q, keyInput: { $0.changeToRough() }),
                Action(name: "Remove Rough".localized, key: .w, keyInput: { $0.removeRough() }),
                Action(name: "Swap Rough".localized, description:
                    "Exchange with drawn line and line of rough layer".localized,
                    key: .e, keyInput: { $0.swapRough() })
                ]),
            ActionNode(actions: [
                Action(name: "Hide".localized, description:
                    "If canvas, Semitransparent display & invalidation judgment of indicated cell, if timeline, hide edit group".localized,
                       key: .h, keyInput: { $0.hideCell() }),
                Action(name: "Show".localized, description:
                    "If canvas, show all cells, if timeline, show edit group".localized,
                       key: .j, keyInput: { $0.showCell() }),
                ]),
            ActionNode(actions: [
                Action(name: "Add Line Point".localized, description:
                    "Add control point that divides control line of indicated line in half".localized,
                       quasimode: [.shift], key: .a, keyInput: { $0.addPoint() }),
                Action(name: "Remove Line Point".localized, description:
                    "Remove control point of indicated line".localized,
                       quasimode: [.shift], key: .d, keyInput: { $0.deletePoint() }),
                Action(name: "Move Line Point".localized, description:
                    "Move indicated control point by dragging (Line ends will snap each other)".localized,
                       quasimode: [.shift],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .movePoint : .none }, drag: { $0.movePoint(with: $1) }),
                Action(name: "Warp Line".localized, description:
                    "Move indicated end of line by dragging (Move snap line ends together)".localized,
                       quasimode: [.shift, .option],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .warpLine : .none }, drag: { $0.warpLine(with: $1) })
                ]),
            ActionNode(actions: [
                Action(name: "Move Z".localized, description:
                    "Change overlapping order of indicated cells by up and down drag".localized,
                       quasimode: [.option],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .moveZ : .none }, drag: { $0.moveZ(with: $1) }),
                Action(name: "Move".localized, description:
                    "If canvas, move indicated cell by dragging, if timeline, change group order by up and down dragging".localized,
                       quasimode: [.control],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .move : .none }, drag: { $0.move(with: $1) }),
                Action(name: "Warp".localized, description:
                    "Warp indicated cell by dragging".localized,
                       quasimode: [.control, .shift],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .warp : .none }, drag: { $0.warp(with: $1) }),
                Action(name: "Transform".localized, description:
                    "Transform indicated cell with selected property by dragging".localized,
                       quasimode: [.control, .option],
                       changeQuasimode: { $0.cutQuasimode = $1 ? .transform : .none }, drag: { $0.transform(with: $1) })
                ]),
            ActionNode(actions: [
                Action(name: "Slow".localized, description:
                    "If canvas, decrease of stroke control point, if color picker, decrease drag speed".localized,
                       quasimode: [.command], drag: { $0.slowDrag(with: $1) })
                ]),
            ActionNode(actions: [
                Action(name: "Scroll".localized, description:
                    "If canvas, move XY, if timeline, selection time with left and right scroll, selection group with up and down scroll".localized,
                       gesture: .scroll),
                Action(name: "Zoom".localized, description:
                    "If canvas, Zoom in/ out, if timeline, change frame size".localized,
                       gesture: .pinch),
                Action(name: "Rotate".localized, description:
                    "Canvas only".localized,
                       gesture: .rotate),
                Action(name: "Reset View".localized, description:
                    "Initialize changed display by gesture other than time and group selection".localized,
                       gesture: .doubleTap)
                ]),
            ActionNode(actions: [
                Action(name: "Look Up".localized, gesture: .tap)
                ]),
            ])
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private var token: NSObjectProtocol?
    func setup() {
        wantsLayer = true
        if let layer = layer {
            layer.backgroundColor = Defaults.backgroundColor.cgColor
            
            rootView.allViews {
                $0.screen = self
            }
            rootView.layer = layer
            responder = rootView
            descriptionView.delegate = self
            
            token = NotificationCenter.default.addObserver(forName: .NSViewFrameDidChange, object: self, queue: nil) {
                ($0.object as? Screen)?.updateFrame()
            }
        }
    }
    
    deinit {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
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
            rootView.allViews {
                $0.contentsScale = backingScaleFactor
            }
        }
    }
    
    func createTrackingArea() {
        let options: NSTrackingAreaOptions = [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited]
        addTrackingArea(NSTrackingArea(rect: bounds, options: options, owner: self))
    }
    override func updateTrackingAreas() {
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }
        createTrackingArea()
        super.updateTrackingAreas()
    }
    
    func updateFrame() {
        CATransaction.disableAnimation {
            contentView.frame = bounds
            descriptionView.frame = CGRect(x: 0.0, y: rootView.frame.height - descriptionHeight, width: rootView.frame.width, height: descriptionHeight)
        }
    }
    
    func point(from event: NSEvent) -> CGPoint {
        return convertToLayer(convert(event.locationInWindow, from: nil))
    }
    var currentPoint: CGPoint {
        let windowPoint = window?.mouseLocationOutsideOfEventStream ?? NSPoint()
        return convertToLayer(convert(windowPoint, from: nil))
    }
    func convertFromTopScreen(_ p: NSPoint) -> NSPoint {
        let windowPoint = window?.convertFromScreen(NSRect(origin: p, size: NSSize())).origin ?? NSPoint()
        return convert(windowPoint, from: nil)
    }
    func convertToTopScreen(_ r: CGRect) -> NSRect {
        return window?.convertToScreen(convert(r, to: nil)) ?? NSRect()
    }
    
    var actionNode = Screen.defaultActionNode
    
    var rootView = View() {
        didSet {
            oldValue.allViews {
                $0.screen = nil
            }
            rootView.allViews {
                $0.screen = self
            }
            rootView.layer = layer ?? CALayer()
        }
    }
    var rootPanelView = View() {
        didSet {
            rootView.children = [contentView, rootPanelView]
        }
    }
    var contentView = View() {
        didSet {
            rootView.children = [contentView, rootPanelView]
        }
    }
    var descriptionView = StringView(isEnabled: true), descriptionHeight = 30.0.cf
    var responder = View() {
        didSet {
            oldValue.allParents {
                $0.indication = false
            }
            oldValue.mainIndication = false
            
            responder.allParents {
                $0.indication = true
            }
            responder.mainIndication = true
        }
    }
    
    func undo(with undoManager: UndoManager) {
        if undoManager.canUndo {
            undoManager.undo()
        } else {
            tempNotAction()
        }
    }
    func redo(with undoManager: UndoManager) {
        if undoManager.canRedo {
            undoManager.redo()
        } else {
            tempNotAction()
        }
    }
    
    func copy(_ string: String, forType type: String, from view: View) {
        let pasteboard = NSPasteboard.general()
        pasteboard.declareTypes([type], owner: nil)
        pasteboard.setString(string, forType: type)
        view.highlight()
    }
    func copy(_ data: Data, forType type: String, from view: View) {
        let pasteboard = NSPasteboard.general()
        pasteboard.declareTypes([type], owner: nil)
        pasteboard.setData(data, forType: type)
        view.highlight()
    }
    func copyString(forType type: String) -> String? {
        return NSPasteboard.general().string(forType: type)
    }
    func copyData(forType type: String) -> Data? {
        return NSPasteboard.general().data(forType: type)
    }
    
    let minPasteImageWidth = 400.0.cf
    func pasteInRootView() {
        let pasteboard = NSPasteboard.general()
        let urlOptions: [String : Any] = [NSPasteboardURLReadingContentsConformToTypesKey: NSImage.imageTypes()]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: urlOptions) as? [URL], !urls.isEmpty {
            let p = rootView.currentPoint
            for url in urls {
                rootView.addChild(makeImageView(url: url, position: p))
            }
        } else {
            tempNotAction()
        }
    }
    private func makeImageView(url :URL, position p: CGPoint) -> ImageView {
        let imageView = ImageView()
        imageView.image = NSImage(byReferencing: url)
        let size = imageView.image.bitmapSize
        let maxWidth = max(size.width, size.height)
        let ratio = minPasteImageWidth < maxWidth ? minPasteImageWidth/maxWidth : 1
        let width = ceil(size.width*ratio), height = ceil(size.height*ratio)
        imageView.frame = CGRect(x: round(p.x - width/2), y: round(p.y - height/2), width: width, height: height)
        return imageView
    }
    
    func changeString(stringView: StringView, string: String, oldString: String, type: StringView.SendType) {
        if string.isEmpty {
            descriptionView.removeFromParent()
        }
    }
    private var popover = NSPopover()
    func showDescription(_ description: String, from view: View) {
        let vc = NSViewController(), tv = NSTextField(frame: CGRect())
        tv.stringValue = description
        tv.font = Defaults.font
        tv.isBordered = false
        tv.drawsBackground = false
        tv.isEditable = false
        tv.isSelectable = true
        tv.sizeToFit()
        tv.frame.origin = CGPoint(x: 5, y: 5)
        let v = NSView(frame: tv.bounds.inset(by: -5))
        v.addSubview(tv)
        vc.view = v
        popover.close()
        popover = NSPopover()
        popover.animates = false
        popover.contentViewController = vc
        popover.show(relativeTo: view.convert(toScreen: view.bounds), of: self, preferredEdge: .minY)
    }
    
    func errorNotification(_ error: Error) {
        if let window = window {
            NSAlert(error: error).beginSheetModal(for: window)
        }
    }
    func infoNotification(_ string: String) {
        rootView.highlight(color: NSColor.red)
    }
    func noAction() {
        rootView.highlight(color: Defaults.noActionColor)
    }
    func tempNotAction() {
        rootView.highlight(color: Defaults.tempNotActionColor)
    }
    
    func addViewInRootPanel(_ view: View, point: CGPoint, from fromView: View) {
        CATransaction.disableAnimation {
            view.frame.origin = rootView.convert(point, from: fromView)
            rootPanelView.addChild(view)
        }
    }
    
    private var isKey = false, keyAction = Action(), keyEvent: NSEvent?
    private weak var keyTextView: TextView?
    override func keyDown(with event: NSEvent) {
        if popover.isShown {
            popover.close()
        }
        if !responder.willKeyInput() {
            isKey = false
        } else if !isDown {
            isKey = true
            keyAction = actionNode.actionWith(gesture: .keyInput, event: event) ?? Action()
            
            if let editTextView = editTextView, keyAction.canTextKeyInput() {
                keyTextView = editTextView
                editTextView.keyInput(with: event)
            } else if keyAction != Action() {
                keyAction.keyInput?(responder)
            } else {
                tempNotAction()
            }
        } else {
            keyEvent = event
        }
    }
    override func keyUp(with event: NSEvent) {
        if let keyTextView = keyTextView, isKey {
            keyTextView.keyInput(with: event)
            self.keyTextView = nil
        }
    }
    
    private var oldQuasimodeAction = Action()
    private weak var oldQuasimodeView: View?
    override func flagsChanged(with event: NSEvent) {
        if !isDown, let oldQuasimodeView = oldQuasimodeView {
            oldQuasimodeAction.changeQuasimode?(oldQuasimodeView, false)
            self.oldQuasimodeView = nil
        }
        let quasimodeAction = actionNode.actionWith(gesture: .drag, event: event) ?? Action()
        if !isDown {
            quasimodeAction.changeQuasimode?(responder, true)
        }
        oldQuasimodeAction = quasimodeAction
        oldQuasimodeView = responder
    }
    
    override func mouseEntered(with event: NSEvent) {
        mouseMoved(with: event)
    }
    override func mouseExited(with event: NSEvent) {
        mouseMoved(with: event)
    }
    override func mouseMoved(with event: NSEvent) {
        let p = point(from: event)
        setResponder(with: p)
        updateCursor(with: p)
        responder.moveCursor(with: MoveEvent(sendType: .sending, nsEvent: event))
    }
    
    func setResponderFromCurrentPoint() {
        setResponder(with: currentPoint)
    }
    func setResponder(with p: CGPoint) {
        let hitView = rootView.atPoint(p) ?? contentView
        if responder !== hitView {
            responder = hitView
        }
    }
    func updateCursor(with p: CGPoint) {
        let cursor = responder.cursor(with: responder.convert(fromScreen: p))
        if cursor != NSCursor.current() {
            cursor.set()
        }
    }
    
    private let defaultDragAction = Action(drag: { $0.drag(with: $1) })
    private var isDown = false, isDrag = false, dragAction = Action()
    private weak var dragView: View?
    override func mouseDown(with nsEvent: NSEvent) {
        if popover.isShown {
            popover.close()
        }
        isDown = true
        isDrag = false
        dragView = responder
        if let dragView = dragView {
            let event = DragEvent(sendType: .begin, nsEvent: nsEvent)
            if !dragView.willDrag(with: event) {
                isDown = false
            } else {
                dragAction = actionNode.actionWith(gesture: .drag, event: nsEvent) ?? defaultDragAction
                dragAction.drag?(dragView, event)
            }
        }
    }
    override func mouseDragged(with nsEvent: NSEvent) {
        isDrag = true
        if isDown, let dragView = dragView {
            dragAction.drag?(dragView, DragEvent(sendType: .sending, nsEvent: nsEvent))
        }
    }
    override func mouseUp(with nsEvent: NSEvent) {
        if isDown {
            let event = DragEvent(sendType: .end, nsEvent: nsEvent)
            if let dragView = dragView {
                dragAction.drag?(dragView, event)
            }
            if !isDrag {
                dragView?.click(with: event)
            }
            isDown = false
            isDrag = false
            
            if let keyEvent = keyEvent {
                keyDown(with: keyEvent)
                self.keyEvent = nil
            }
            
            if dragAction != oldQuasimodeAction {
                if let dragView = dragView {
                    dragAction.changeQuasimode?(dragView, false)
                }
                oldQuasimodeAction.changeQuasimode?(responder, true)
            }
        }
    }
    
    private weak var momentumScrollView: View?
    override func scrollWheel(with event: NSEvent) {
        if event.phase != .mayBegin && event.phase != .cancelled {
            mouseMoved(with: event)
            if event.momentumPhase != .changed && event.momentumPhase != .ended {
                momentumScrollView = responder
            }
            let sendType: ScrollEvent.SendType = event.phase == .began ? .begin : (event.phase == .ended ? .end : .sending)
            momentumScrollView?.scroll(with: ScrollEvent(sendType: sendType, nsEvent: event) )
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
                responder.zoom(with: PinchEvent(sendType: .begin, nsEvent: event))
            }
        } else if event.phase == .ended {
            if blockGesture == .pinch {
                blockGesture = .none
                responder.zoom(with: PinchEvent(sendType: .end, nsEvent: event))
            }
        } else {
            if blockGesture == .pinch {
                responder.zoom(with: PinchEvent(sendType: .sending, nsEvent: event))
            }
        }
    }
    override func rotate(with event: NSEvent) {
        if event.phase == .began {
            if blockGesture == .none {
                blockGesture = .rotate
                responder.rotate(with: RotateEvent(sendType: .begin, nsEvent: event))
            }
        } else if event.phase == .ended {
            if blockGesture == .rotate {
                blockGesture = .none
                responder.rotate(with: RotateEvent(sendType: .end, nsEvent: event))
            }
        } else {
            if blockGesture == .rotate {
                responder.rotate(with: RotateEvent(sendType: .sending, nsEvent: event))
            }
        }
    }
    
    override func quickLook(with event: NSEvent) {
        responder.quickLook()
    }
    override func smartMagnify(with event: NSEvent) {
        responder.reset()
    }
    
    var editTextView: TextView? {
        return responder as? TextView
    }
    
    func hasMarkedText() -> Bool {
        return editTextView?.hasMarkedText() ?? false
    }
    func markedRange() -> NSRange {
        return editTextView?.markedRange() ?? NSRange()
    }
    func selectedRange() -> NSRange {
        return editTextView?.selectedRange() ?? NSRange()
    }
    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        editTextView?.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }
    func unmarkText() {
        editTextView?.unmarkText()
    }
    func validAttributesForMarkedText() -> [String] {
        return editTextView?.validAttributesForMarkedText() ?? []
    }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        return editTextView?.attributedSubstring(forProposedRange: range, actualRange: actualRange)
    }
    func insertText(_ string: Any, replacementRange: NSRange) {
        editTextView?.insertText(string, replacementRange: replacementRange)
    }
    func characterIndex(for point: NSPoint) -> Int {
        return editTextView?.characterIndex(for: point) ?? 0
    }
    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        return editTextView?.firstRect(forCharacterRange: range, actualRange: actualRange) ?? NSRect()
    }
    func attributedString() -> NSAttributedString {
        return editTextView?.attributedString() ?? NSAttributedString()
    }
    func fractionOfDistanceThroughGlyph(for point: NSPoint) -> CGFloat {
        return editTextView?.fractionOfDistanceThroughGlyph(for: point) ?? 0
    }
    func baselineDeltaForCharacter(at anIndex: Int) -> CGFloat {
        return editTextView?.baselineDeltaForCharacter(at: anIndex) ?? 0
    }
    func windowLevel() -> Int {
        return window?.level ?? 0
    }
    func drawsVerticallyForCharacter(at charIndex: Int) -> Bool {
        return editTextView?.drawsVerticallyForCharacter(at: charIndex) ?? false
    }
    
    override func insertNewline(_ sender: Any?) {
        editTextView?.insertNewline()
    }
    override func insertTab(_ sender: Any?) {
        editTextView?.insertTab()
    }
    override func deleteBackward(_ sender: Any?) {
        editTextView?.deleteBackward()
    }
    override func deleteForward(_ sender: Any?) {
        editTextView?.deleteForward()
    }
    override func moveLeft(_ sender: Any?) {
        editTextView?.moveLeft()
    }
    override func moveRight(_ sender: Any?) {
        editTextView?.moveRight()
    }
}

class View: Equatable {
    var description = "No description".localized
    var layer: CALayer
    
    init(layer: CALayer = CALayer.interfaceLayer()) {
        self.layer = layer
        self.borderWidth = 0.5
        self.borderColor = Defaults.backgroundColor.cgColor
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor
    }
    
    weak fileprivate(set) var screen: Screen?
    
    private(set) weak var parent: View? {
        didSet {
            let screen = parent?.screen, contentsScale = parent?.contentsScale ?? 1
            allViews {
                $0.screen = screen
                $0.contentsScale = contentsScale
            }
        }
    }
    private var _children = [View]()
    var children: [View] {
        get {
            return _children
        }
        set {
            CATransaction.disableAnimation {
                for child in _children {
                    child.parent = nil
                    child.layer.removeFromSuperlayer()
                }
                for child in newValue {
                    child.parent = self
                    layer.addSublayer(child.layer)
                }
                _children = newValue
                screen?.setResponderFromCurrentPoint()
            }
        }
    }
    func addChild(_ child: View) {
        _children.append(child)
        child.parent = self
        CATransaction.disableAnimation {
            layer.addSublayer(child.layer)
        }
        screen?.setResponderFromCurrentPoint()
    }
    func insertChild(_ child: View, at i: Int) {
        _children.insert(child, at:i)
        child.parent = self
        CATransaction.disableAnimation {
            layer.insertSublayer(child.layer, at: UInt32(i))
        }
        screen?.setResponderFromCurrentPoint()
    }
    func removeFromParent() {
        if parent != nil {
            let screen = self.screen
            if let index = parent?.children.index(of: self) {
                parent?.children.remove(at: index)
            }
            parent = nil
            CATransaction.disableAnimation {
                layer.removeFromSuperlayer()
            }
            screen?.setResponderFromCurrentPoint()
        }
    }
    
    func allParents(handler: (View) -> Void) {
        handler(self)
        parent?.allParents(handler: handler)
    }
    func allViews(handler: (View) -> Void) {
        allViewsRecursion(handler)
    }
    private func allViewsRecursion(_ handler: (View) -> Void) {
        handler(self)
        for child in children {
            child.allViewsRecursion(handler)
        }
    }
    
    var borderColor: CGColor {
        didSet {
            layer.borderColor = borderColor
        }
    }
    var borderWidth: CGFloat {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    private var timer: LockTimer?
    func highlight(color: NSColor = Defaults.selectionColor) {
        if timer == nil {
            timer = LockTimer()
        }
        timer?.begin(0.1, beginHandler: { [unowned self] in
            CATransaction.disableAnimation {
                self.layer.borderColor = color.cgColor
                self.layer.borderWidth = 2
            }
        }, endHandler: { [unowned self] in
            self.layer.borderColor = self.borderColor
            self.layer.borderWidth = self.borderWidth
            self.timer = nil
        })
    }
    
    var indicatable = true, indication = false, mainIndication = false
    func atPoint(_ point: CGPoint) -> View? {
        if !layer.isHidden {
            let inPoint = layer.convert(point, from: parent?.layer)
            for child in children.reversed() {
                let view = child.atPoint(inPoint)
                if view != nil {
                    return view
                }
            }
            return contains(inPoint) ? self : nil
        }
        return nil
    }
    
    static func == (lhs: View, rhs: View) -> Bool {
        return lhs === rhs
    }
    
    func contains(_ p: CGPoint) -> Bool {
        return indicatable && !layer.isHidden ? layer.contains(p) : false
    }
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            screen?.setResponderFromCurrentPoint()
        }
    }
    var bounds: CGRect {
        get {
            return layer.bounds
        }
        set {
            layer.bounds = newValue
        }
    }
    var contentsScale: CGFloat {
        get {
            return layer.contentsScale
        }
        set {
            layer.contentsScale = newValue
        }
    }
    func point(from event: Event) -> CGPoint {
        return convert(fromScreen: screen?.convert(event.locationInWindow, from: nil) ?? CGPoint())
    }
    func convert(fromScreen p: CGPoint) -> CGPoint {
        return layer.convert(p, from: screen?.layer)
    }
    func convert(toScreen p: CGPoint) -> CGPoint {
        return screen?.layer?.convert(p, from: layer) ?? CGPoint()
    }
    func convert(toScreen rect: CGRect) -> CGRect {
        return screen?.layer?.convert(rect, from: layer) ?? CGRect()
    }
    func convert(_ point: CGPoint, from view: View?) -> CGPoint {
        return layer.convert(point, from: view?.layer)
    }
    func convert(_ point: CGPoint, to view: View?) -> CGPoint {
        return layer.convert(point, to: view?.layer)
    }
    var currentPoint: CGPoint {
        return convert(fromScreen: screen?.currentPoint ?? CGPoint())
    }
    
    func cursor(with p: CGPoint) -> NSCursor {
        return NSCursor.arrow()
    }
    
    var sendParent: View? {
        if parent == nil {
            screen?.noAction()
        }
        return parent
    }
    
    var undoManager: UndoManager? {
        return screen?.undoManager
    }
    func undo() {
        if parent == nil {
            if let undoManager = undoManager {
                screen?.undo(with: undoManager)
            }
        } else {
            parent?.undo()
        }
    }
    func redo() {
        if parent == nil {
            if let undoManager = undoManager {
                screen?.redo(with: undoManager)
            }
        } else {
            parent?.redo()
        }
    }
    
    func cut() {
        copy()
        delete()
    }
    func copy() {
        sendParent?.copy()
    }
    func paste() {
        screen?.pasteInRootView()
    }
    func delete() {
        sendParent?.delete()
    }
    
    func moveToPrevious() {
        sendParent?.moveToPrevious()
    }
    func moveToNext() {
        sendParent?.moveToNext()
    }
    func play() {
        sendParent?.play()
    }
    
    func addCellWithLines() {
        sendParent?.addCellWithLines()
    }
    func addAndClipCellWithLines() {
        sendParent?.addAndClipCellWithLines()
    }
    func replaceCellLines() {
        sendParent?.replaceCellLines()
    }
    func lassoDelete() {
        sendParent?.lassoDelete()
    }
    func lassoSelect() {
        sendParent?.lassoSelect()
    }
    func lassoDeleteSelect() {
        sendParent?.lassoDeleteSelect()
    }
    func clipCellInSelection() {
        sendParent?.clipCellInSelection()
    }
    
    func hideCell() {
        sendParent?.hideCell()
    }
    func showCell() {
        sendParent?.showCell()
    }
    func pasteCell() {
        sendParent?.pasteCell()
    }
    
    func copyAndBindMaterial() {
        sendParent?.copyAndBindMaterial()
    }
    func pasteMaterial() {
        sendParent?.pasteMaterial()
    }
    func splitColor() {
        sendParent?.splitColor()
    }
    func splitOtherThanColor() {
        sendParent?.splitOtherThanColor()
    }
    
    func changeToRough() {
        sendParent?.changeToRough()
    }
    func removeRough() {
        sendParent?.removeRough()
    }
    func swapRough() {
        sendParent?.swapRough()
    }
    
    func addPoint() {
        sendParent?.addPoint()
    }
    func deletePoint() {
        sendParent?.deletePoint()
    }
    
    func moveCursor(with event: MoveEvent) {
        parent?.moveCursor(with: event)
    }
    func willKeyInput() -> Bool {
        return parent?.willKeyInput() ?? true
    }
    func willDrag(with event: DragEvent) -> Bool {
        return parent?.willDrag(with: event) ?? true
    }
    func click(with event: DragEvent) {
        parent?.click(with: event)
    }
    func drag(with event: DragEvent) {
        sendParent?.drag(with: event)
    }
    func slowDrag(with event: DragEvent) {
        sendParent?.slowDrag(with: event)
    }
    
    var cutQuasimode = CutView.Quasimode.none
    func movePoint(with event: DragEvent) {
        sendParent?.movePoint(with: event)
    }
    func warpLine(with event: DragEvent) {
        sendParent?.warpLine(with: event)
    }
    func moveZ(with event: DragEvent) {
        sendParent?.moveZ(with: event)
    }
    func move(with event: DragEvent) {
        sendParent?.move(with: event)
    }
    func warp(with event: DragEvent) {
        sendParent?.warp(with: event)
    }
    func transform(with event: DragEvent) {
        sendParent?.transform(with: event)
    }
    
    func scroll(with event: ScrollEvent) {
        sendParent?.scroll(with: event)
    }
    func zoom(with event: PinchEvent) {
        sendParent?.zoom(with: event)
    }
    func rotate(with event: RotateEvent) {
        sendParent?.rotate(with: event)
    }
    func reset() {
        sendParent?.reset()
    }
    func quickLook() {
        screen?.showDescription(description, from: self)
    }
}

struct ActionNode {
    var name: String, action: Action?, children: [ActionNode]
    
    init(name: String = "", action: Action? = nil, children: [ActionNode] = []) {
        self.name = name
        self.action = action
        self.children = children
        updateActions()
    }
    init(actions: [Action]) {
        name = ""
        action = nil
        children = actions.map { ActionNode(action: $0) }
        updateActions()
    }
    
    mutating func updateActions() {
        for child in children {
            keyActions += child.keyActions
            clickActions += child.clickActions
            rightClickActions += child.rightClickActions
            dragActions += child.dragActions
        }
        if let action = action {
            switch action.gesture {
            case .keyInput:
                keyActions.append(action)
            case .click:
                clickActions.append(action)
            case .rightClick:
                rightClickActions.append(action)
            case .drag:
                dragActions.append(action)
            default:
                break
            }
        }
    }
    
    private var keyActions = [Action](), clickActions = [Action](), rightClickActions = [Action](), dragActions = [Action]()
    func actionWith(gesture: Action.Gesture, event: NSEvent) -> Action? {
        switch gesture {
        case .keyInput:
            for action in keyActions {
                if action.canSend(with: event) {
                    return action
                }
            }
        case .click:
            for action in clickActions {
                if action.canSend(with: event) {
                    return action
                }
            }
        case .rightClick:
            for action in rightClickActions {
                if action.canSend(with: event) {
                    return action
                }
            }
        case .drag:
            for action in dragActions {
                if action.canSend(with: event) {
                    return action
                }
            }
        default:
            break
        }
        return nil
    }
}

protocol Event {
    var locationInWindow: CGPoint { get }
    var time: TimeInterval { get }
}
struct MoveEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    
    fileprivate init(sendType: SendType, nsEvent: NSEvent) {
        self.sendType = sendType
        locationInWindow = nsEvent.locationInWindow
        self.time = nsEvent.timestamp
    }
}
struct DragEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let pressure: Float
    
    fileprivate init(sendType: SendType, nsEvent: NSEvent) {
        self.sendType = sendType
        locationInWindow = nsEvent.locationInWindow
        self.time = nsEvent.timestamp
        self.pressure = nsEvent.pressure
    }
}
struct ScrollEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let scrollDeltaPoint: CGPoint, scrollMomentum: NSEventPhase
    
    fileprivate init(sendType: SendType, nsEvent: NSEvent) {
        self.sendType = sendType
        locationInWindow = nsEvent.locationInWindow
        self.time = nsEvent.timestamp
        scrollDeltaPoint = CGPoint(x: nsEvent.scrollingDeltaX, y: nsEvent.scrollingDeltaY)
        scrollMomentum = nsEvent.momentumPhase
    }
}
struct PinchEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let magnification: CGFloat
    
    fileprivate init(sendType: SendType, nsEvent: NSEvent) {
        self.sendType = sendType
        locationInWindow = nsEvent.locationInWindow
        self.time = nsEvent.timestamp
        magnification = nsEvent.magnification
    }
}
struct RotateEvent: Event {
    enum SendType {
        case begin, sending, end
    }
    let sendType: SendType, locationInWindow: CGPoint, time: TimeInterval
    let rotation: CGFloat
    
    fileprivate init(sendType: SendType, nsEvent: NSEvent) {
        self.sendType = sendType
        locationInWindow = nsEvent.locationInWindow
        self.time = nsEvent.timestamp
        rotation = nsEvent.rotation.cf
    }
}

struct Action: Equatable {
    struct Quasimode: OptionSet {
        var rawValue: Int32
        static let shift = Quasimode(rawValue: 1), command = Quasimode(rawValue: 2)
        static let control = Quasimode(rawValue:4), option = Quasimode(rawValue: 8)
        
        func contains(_ event: NSEvent) -> Bool {
            var modifierFlags: NSEventModifierFlags = []
            if contains(.shift) {
                modifierFlags.insert(.shift)
            }
            if contains(.command) {
                modifierFlags.insert(.command)
            }
            if contains(.control) {
                modifierFlags.insert(.control)
            }
            if contains(.option) {
                modifierFlags.insert(.option)
            }
            
            let flipModifierFlags = modifierFlags.symmetricDifference([.shift, .command, .control, .option])
            return event.modifierFlags.contains(modifierFlags) && event.modifierFlags.intersection(flipModifierFlags) == []
        }
        
        var displayString: String {
            var string = intersection(.option) != [] ? "option" : ""
            if intersection(.shift) != [] {
                string += string.isEmpty ? "shift" : " shift"
            }
            if intersection(.control) != [] {
                string += string.isEmpty ? "control" : " control"
            }
            if intersection(.command) != [] {
                string += string.isEmpty ? "command" : " command"
            }
            return string
        }
    }
    
    struct Key {
        let code: UInt16, string: String
        static let
        a = Key(code: 0, string: "A"), s = Key(code: 1, string: "S"), d = Key(code: 2, string: "D"), f = Key(code: 3, string: "F"),
        h = Key(code: 4, string: "H"), g = Key(code: 5, string: "G"),  z = Key(code: 6, string: "Z"), x = Key(code: 7, string: "X"),
        c = Key(code: 8, string: "C"), v = Key(code: 9, string: "V"), b = Key(code: 11, string: "B"),
        q = Key(code: 12, string: "Q"), w = Key(code: 13, string: "W"), e = Key(code: 14, string: "E"), r = Key(code: 15, string: "R"),
        y = Key(code: 16, string: "Y"), t = Key(code: 17, string: "t"), num1 = Key(code: 18, string: "1"), num2 = Key(code: 19, string: "2"),
        num3 = Key(code: 20, string: "3"), num4 = Key(code: 21, string: "4"), num6 = Key(code: 22, string: "6"), num5 = Key(code: 23, string: "5"),
        equals = Key(code: 24, string: "="), num9 = Key(code: 25, string: "9"), num7 = Key(code: 26, string: "7"), minus = Key(code: 27, string: "-"),
        num8 = Key(code: 28, string: "8"), num0 = Key(code: 29, string: "0"), rightBracket = Key(code: 30, string: "]"), o = Key(code: 31, string: "O"),
        u = Key(code: 32, string: "U"), leftBracket = Key(code: 33, string: "["), i = Key(code: 34, string: "I"), p = Key(code: 35, string: "P"),
        `return` = Key(code: 36, string: "return"), l = Key(code: 37, string: "L"), j = Key(code: 38, string: "J"), apostrophe = Key(code: 39, string: "`"),
        k = Key(code: 40, string: "K"), semicolon = Key(code: 41, string: ";"), frontslash = Key(code: 42, string: "\\"), comma = Key(code: 43, string: ","),
        backslash = Key(code: 44, string: "/"), n = Key(code: 45, string: "N"), m = Key(code: 46, string: "M"), period = Key(code: 47, string: "."),
        tab = Key(code: 48, string: "tab"), space = Key(code: 49, string: "space"), backApostrophe = Key(code: 50, string: "^"), delete = Key(code: 51, string: "delete"),
        escape = Key(code: 53, string: "esc"), command = Key(code: 55, string: "command"),
        shiht = Key(code: 56, string: "shiht"), option = Key(code: 58, string: "option"), control = Key(code: 59, string: "control"),
        up = Key(code: 126, string: "↑"), down = Key(code: 125, string: "↓"), left = Key(code: 123, string: "←"), right = Key(code: 124, string: "→")
    }
    
    enum Gesture: UInt16 {
        case keyInput, click, rightClick, drag, scroll, pinch, rotate, tap, doubleTap
        var displayString: String {
            switch self {
            case .keyInput, .drag:
                return ""
            case .click:
                return "Tap".localized
            case .rightClick:
                return "Two Finger Tap".localized
            case .scroll:
                return "Two Finger Drag".localized
            case .pinch:
                return "Two Finger Pinch".localized
            case .rotate:
                return "Two Finger Rotate".localized
            case .tap:
                return "\"Look up\" Gesture".localized
            case .doubleTap:
                return "Two Finger Double Tap".localized
            }
        }
    }
    
    var name: String, description: String, quasimode: Quasimode, key: Key?, gesture: Gesture
    var keyInput: ((View) -> Void)?, changeQuasimode: ((View, Bool) -> Void)?, drag: ((View, DragEvent) -> Void)?
    
    init(name: String = "", description: String = "", quasimode: Quasimode = [], key: Key? = nil, gesture: Gesture = .keyInput,
         keyInput: ((View) -> Void)? = nil, changeQuasimode: ((View, Bool) -> Void)? = nil, drag: ((View, DragEvent) -> Void)? = nil) {
        self.name = name
        self.description = description
        self.quasimode = quasimode
        self.key = key
        if keyInput != nil {
            self.gesture = .keyInput
        } else if drag != nil {
            self.gesture = .drag
        } else {
            self.gesture = gesture
        }
        self.keyInput = keyInput
        self.changeQuasimode = changeQuasimode
        self.drag = drag
    }
    
    var displayCommandString: String {
        var displayString = quasimode.displayString
        if let keyDisplayString = key?.string {
            displayString += displayString.isEmpty ? keyDisplayString : " " + keyDisplayString
        }
        if !gesture.displayString.isEmpty {
            displayString += displayString.isEmpty ? gesture.displayString : " " + gesture.displayString
        }
        return displayString
    }
    
    func canSend(with event: NSEvent) -> Bool {
        if let key = key {
            return event.keyCode == key.code && quasimode.contains(event)
        } else {
            return quasimode.contains(event)
        }
    }
    
    func canTextKeyInput() -> Bool {
        return key != nil && !quasimode.contains(.command)
    }
    
    static func == (lhs: Action, rhs: Action) -> Bool {
        return lhs.name == rhs.name
    }
}
