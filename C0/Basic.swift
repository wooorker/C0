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

extension String: CopyData, Drawable {
    static var  name: Localization {
        return Localization(english: "String", japanese: "文字")
    }
    func draw(with bounds: CGRect, in ctx: CGContext) {
        let textFrame = TextFrame(string: self, font: .thumbnail, frameWidth: bounds.width - 2)
        let b = CGRect(
            x: 2, y: bounds.height - textFrame.typographicBounds.height - 2,
            width: bounds.width - 2, height: bounds.height - 2
        )
        textFrame.draw(in: b, in: ctx)
    }
    static func with(_ data: Data) -> String? {
        return String(data: data, encoding: .utf8)
    }
    var data: Data {
        return data(using: .utf8) ?? Data()
    }
    var calculate: String {
        return (NSExpression(format: self).expressionValue(with: nil, context: nil) as? NSNumber)?.stringValue ?? "Error"
    }
    func union(_ other: String, space: String = " ") -> String {
        return other.isEmpty ? self : (isEmpty ? other : self + space + other)
    }
}

struct Layout {
    static let basicPadding = 3.0.cf, basicLargePadding = 14.0.cf
    static let basicHeight = Font.small.ceilHeight(withPadding: 1) + basicPadding * 2
    static func centered(_ responders: [Respondable], in bounds: CGRect, paddingWidth: CGFloat = 0) {
        let w = responders.reduce(-paddingWidth) { $0 +  $1.frame.width + paddingWidth }
        _ = responders.reduce(floor((bounds.width - w) / 2)) { x, responder in
            responder.frame.origin.x = x
            return x + responder.frame.width + paddingWidth
        }
    }
    static func leftAlignment(_ responders: [Respondable], minX: CGFloat = basicPadding, height: CGFloat, paddingWidth: CGFloat = 0) {
        _ = responders.reduce(minX) { x, responder in
            responder.frame.origin = CGPoint(x: x, y: round((height - responder.frame.height) / 2))
            return x + responder.frame.width + paddingWidth
        }
    }
    static func autoHorizontalAlignment(_ responders: [Respondable], padding: CGFloat = 0, in bounds: CGRect) {
        guard !responders.isEmpty else {
            return
        }
        let w = responders.reduce(0.0.cf) { $0 +  $1.editBounds.width + padding } - padding
        let dx = (bounds.width - w) / responders.count.cf
        _ = responders.enumerated().reduce(bounds.minX) { x, value in
            if value.offset == responders.count - 1 {
                value.element.frame = CGRect(x: x, y: bounds.minY, width: bounds.maxX - x, height: bounds.height)
                return bounds.maxX
            } else {
                value.element.frame = CGRect(
                    x: x, y: bounds.minY, width: round(value.element.editBounds.width + dx), height: bounds.height
                )
                return x + value.element.frame.width + padding
            }
        }
    }
}

struct Localization {
    var baseLanguageCode: String, base: String, values: [String: String]
    init(baseLanguageCode: String, base: String, values: [String: String]) {
        self.baseLanguageCode = baseLanguageCode
        self.base = base
        self.values = values
    }
    init(_ noLocalizeString: String) {
        baseLanguageCode = "en"
        base = noLocalizeString
        values = [:]
    }
    init(english: String = "", japanese: String = "") {
        baseLanguageCode = "en"
        base = english
        values = ["ja": japanese]
    }
    var currentString: String {
        return string(with: Locale.current)
    }
    func string(with locale: Locale) -> String {
        if let languageCode = locale.languageCode, let value = values[languageCode] {
            return value
        }
        return base
    }
    var isEmpty: Bool {
        return base.isEmpty
    }
    static func + (lhs: Localization, rhs: Localization) -> Localization {
        var values = lhs.values
        if rhs.values.isEmpty {
            lhs.values.forEach { values[$0.key] = (values[$0.key] ?? "") + rhs.base }
        } else {
            for v in rhs.values {
                values[v.key] = (lhs.values[v.key] ?? lhs.base) + v.value
            }
        }
        return Localization(baseLanguageCode: lhs.baseLanguageCode, base: lhs.base + rhs.base, values: values)
    }
    static func += (left: inout Localization, right: Localization) {
        for v in right.values {
            left.values[v.key] = (left.values[v.key] ?? left.base) + v.value
        }
        left.base += right.base
    }
    static func == (lhs: Localization, rhs: Localization) -> Bool {
        return lhs.base == rhs.base
    }
}

extension URL: CopyData, Drawable {
    static var  name: Localization {
        return Localization("URL")
    }
    func draw(with bounds: CGRect, in ctx: CGContext) {
        lastPathComponent.draw(with: bounds, in: ctx)
    }
    static func with(_ data: Data) -> URL? {
        if let string = String(data: data, encoding: .utf8) {
            return URL(fileURLWithPath: string)
        } else {
            return nil
        }
    }
    var data: Data {
        return path.data(using: .utf8) ?? Data()
    }
    func isConforms(uti: String) -> Bool {
        if let aUTI = self.uti {
            return UTTypeConformsTo(aUTI as CFString, uti as CFString)
        } else {
            return false
        }
    }
    var uti: String? {
        return (try? resourceValues(forKeys: Set([URLResourceKey.typeIdentifierKey])))?.typeIdentifier
    }
    init?(bookmark: Data?) {
        if let bookmark = bookmark {
            do {
                var bookmarkDataIsStale = false
                if let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &bookmarkDataIsStale) {
                    self = url
                } else {
                    return nil
                }
            } catch {
                return nil
            }
        } else {
            return nil
        }
    }
}

final class LockTimer {
    private var count = 0
    private(set) var wait = false
    func begin(endTimeLength: Second, beginHandler: () -> Void, endHandler: @escaping () -> Void) {
        if wait {
            count += 1
        } else {
            beginHandler()
            wait = true
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + endTimeLength) {
            if self.count == 0 {
                endHandler()
                self.wait = false
            } else {
                self.count -= 1
            }
        }
    }
    private(set) var inUse = false
    private weak var timer: Timer?
    func begin(interval: Second, repeats: Bool = true, tolerance: Second = 0.0, handler: @escaping (Void) -> Void) {
        let time = interval + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, time, repeats ? interval : 0, 0, 0) { _ in
            handler()
        }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        self.timer = timer
        inUse = true
        self.timer?.tolerance = tolerance
    }
    func stop() {
        inUse = false
        timer?.invalidate()
        timer = nil
    }
}
final class Weak<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}

protocol Copying: class {
    var deepCopy: Self { get }
}
extension Array {
    func withRemovedFirst() -> Array {
        var array = self
        array.removeFirst()
        return array
    }
    func withRemovedLast() -> Array {
        var array = self
        array.removeLast()
        return array
    }
    func withRemoved(at i: Int) -> Array {
        var array = self
        array.remove(at: i)
        return array
    }
    func withAppend(_ element: Element) -> Array {
        var array = self
        array.append(element)
        return array
    }
    func withInserted(_ element: Element, at i: Int) -> Array {
        var array = self
        array.insert(element, at: i)
        return array
    }
    func withReplaced(_ element: Element, at i: Int) -> Array {
        var array = self
        array[i] = element
        return array
    }
}
