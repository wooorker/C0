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

let effectiveFieldOfView = tan(.pi * (30.0 / 2.0) / 180.0) / tan(.pi * (20.0 / 2.0) / 180.0)
let basicEffectiveFieldOfView = Q(152, 100)

extension String {
    var calculate: String {
        return (NSExpression(format: self)
            .expressionValue(with: nil, context: nil) as? NSNumber)?.stringValue ?? "Error"
    }
    func union(_ other: String, space: String = " ") -> String {
        return other.isEmpty ? self : (isEmpty ? other : self + space + other)
    }
}
extension String: Referenceable {
    static var  name: Localization {
        return Localization(english: "String", japanese: "文字")
    }
}
extension String: Drawable {
    func responder(with bounds: CGRect) -> Respondable {
        let label = Label(frame: bounds, text: Localization(self), font: .small, isSizeToFit: false)
        label.defaultBorderColor = Color.border.cgColor
        return label
    }
}

struct Layout {
    static let smallPadding = 1.0.cf, basicPadding = 3.0.cf, basicLargePadding = 14.0.cf
    static let basicHeight = Font.default.ceilHeight(withPadding: 1) + basicPadding * 2
    static let smallHeight = Font.small.ceilHeight(withPadding: 1) + smallPadding * 2
    static func centered(_ responders: [Respondable],
                         in bounds: CGRect, paddingWidth: CGFloat = 0) {
        
        let w = responders.reduce(-paddingWidth) { $0 +  $1.frame.width + paddingWidth }
        _ = responders.reduce(floor((bounds.width - w) / 2)) { x, responder in
            responder.frame.origin.x = x
            return x + responder.frame.width + paddingWidth
        }
    }
    static func leftAlignmentWidth(_ responders: [Respondable], minX: CGFloat = basicPadding,
                                   paddingWidth: CGFloat = 0) -> CGFloat {
        return responders.reduce(minX) { $0 + $1.frame.width + paddingWidth } - paddingWidth
    }
    static func leftAlignment(_ responders: [Respondable], minX: CGFloat = basicPadding,
                              y: CGFloat = 0, height: CGFloat, paddingWidth: CGFloat = 0) -> CGSize {
        
        let width = responders.reduce(minX) { x, responder in
            responder.frame.origin = CGPoint(x: x,
                                             y: y + round((height - responder.frame.height) / 2))
            return x + responder.frame.width + paddingWidth
        }
        return CGSize(width: width, height: height)
    }
    static func topAlignment(_ responders: [Respondable],
                             minX: CGFloat = basicPadding, minY: CGFloat = basicPadding,
                             minSize: inout CGSize, padding: CGFloat = Layout.basicPadding) {
        
        let width = responders.reduce(0.0.cf) { max($0, $1.editBounds.width) } + padding * 2
        let height = responders.reversed().reduce(minY) { y, responder in
            responder.frame = CGRect(x: minX, y: y, width: width, height: responder.editBounds.height)
            return y + responder.frame.height
        }
        minSize = CGSize(width: width, height: height - minY)
    }
    static func autoHorizontalAlignment(_ responders: [Respondable],
                                        padding: CGFloat = 0, in bounds: CGRect) {
        
        guard !responders.isEmpty else {
            return
        }
        let w = responders.reduce(0.0.cf) { $0 +  $1.editBounds.width + padding } - padding
        let dx = (bounds.width - w) / responders.count.cf
        _ = responders.enumerated().reduce(bounds.minX) { x, value in
            if value.offset == responders.count - 1 {
                value.element.frame = CGRect(x: x, y: bounds.minY,
                                             width: bounds.maxX - x, height: bounds.height)
                return bounds.maxX
            } else {
                value.element.frame = CGRect(x: x,
                                             y: bounds.minY,
                                             width: round(value.element.editBounds.width + dx),
                                             height: bounds.height)
                return x + value.element.frame.width + padding
            }
        }
    }
}

struct Localization: Codable {
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
    static func +(lhs: Localization, rhs: Localization) -> Localization {
        var values = lhs.values
        if rhs.values.isEmpty {
            lhs.values.forEach { values[$0.key] = (values[$0.key] ?? "") + rhs.base }
        } else {
            for v in rhs.values {
                values[v.key] = (lhs.values[v.key] ?? lhs.base) + v.value
            }
        }
        return Localization(baseLanguageCode: lhs.baseLanguageCode,
                            base: lhs.base + rhs.base,
                            values: values)
    }
    static func +=(lhs: inout Localization, rhs: Localization) {
        for v in rhs.values {
            lhs.values[v.key] = (lhs.values[v.key] ?? lhs.base) + v.value
        }
        lhs.base += rhs.base
    }
    static func ==(lhs: Localization, rhs: Localization) -> Bool {
        return lhs.base == rhs.base
    }
}

extension Data {
    var bytesString: String {
        return ByteCountFormatter().string(fromByteCount: Int64(count))
    }
}

extension URL {
    func isConforms(uti: String) -> Bool {
        if let aUTI = self.uti {
            return UTTypeConformsTo(aUTI as CFString, uti as CFString)
        } else {
            return false
        }
    }
    var uti: String? {
        return (try? resourceValues(forKeys: Set([URLResourceKey.typeIdentifierKey])))?
            .typeIdentifier
    }
    init?(bookmark: Data?) {
        guard let bookmark = bookmark else {
            return nil
        }
        do {
            var bookmarkDataIsStale = false
            guard let url = try URL(resolvingBookmarkData: bookmark,
                                    bookmarkDataIsStale: &bookmarkDataIsStale) else {
                return nil
            }
            self = url
        } catch {
            return nil
        }
    }
}
extension URL: Referenceable {
    static var  name: Localization {
        return Localization("URL")
    }
}
extension URL: Drawable {
    func responder(with bounds: CGRect) -> Respondable {
        return lastPathComponent.responder(with: bounds)
    }
}

final class LockTimer {
    private var count = 0
    private(set) var wait = false
    func begin(endDuration: Second, beginHandler: () -> Void, endHandler: @escaping () -> Void) {
        if wait {
            count += 1
        } else {
            beginHandler()
            wait = true
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + endDuration) {
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
    func begin(interval: Second, repeats: Bool = true,
               tolerance: Second = 0.0, handler: @escaping () -> Void) {
        let time = interval + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault,
                                                    time, repeats ? interval : 0, 0, 0) { _ in
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
    var copied: Self { get }
    func copied(from copier: Copier) -> Self
}
extension Copying {
    var copied: Self {
        return Copier().copied(self)
    }
    func copied(from copier: Copier) -> Self {
        return self
    }
}
final class Copier {
    var userInfo = [String: Any]()
    func copied<T: Copying>(_ object: T) -> T {
        let key = String(describing: T.self)
        let oim: ObjectIdentifierManager<T>
        if let o = userInfo[key] as? ObjectIdentifierManager<T> {
            oim = o
        } else {
            oim = ObjectIdentifierManager<T>()
            userInfo[key] = oim
        }
        let objectID = ObjectIdentifier(object)
        if let copiedObject = oim.objects[objectID] {
            return copiedObject
        } else {
            let copiedObject = object.copied(from: self)
            oim.objects[objectID] = copiedObject
            return copiedObject
        }
    }
}
private final class ObjectIdentifierManager<T> {
    var objects = [ObjectIdentifier: T]()
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

protocol Referenceable {
    static var name: Localization { get }
    static var feature: Localization { get }
    var instanceDescription: Localization { get }
    var valueDescription: Localization { get }
}
extension Referenceable {
    static var feature: Localization {
        return Localization()
    }
    var instanceDescription: Localization {
        return Localization()
    }
    var valueDescription: Localization {
        return Localization()
    }
}

extension NSCoder {
    func decodeDecodable<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = decodeObject(forKey: key) as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }
    func encodeEncodable<T: Encodable>(_ object: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(object) {
            encode(data, forKey: key)
        }
    }
}
extension NSCoding {
    static func with(_ data: Data) -> Self? {
        return data.isEmpty ? nil : NSKeyedUnarchiver.unarchiveObject(with: data) as? Self
    }
    var data: Data {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
}

extension Decodable {
    init?(jsonData: Data) {
        if let obj = try? JSONDecoder().decode(Self.self, from: jsonData) {
            self = obj
        } else {
            return nil
        }
    }
}
extension Encodable {
    var jsonData: Data? {
        return try? JSONEncoder().encode(self)
    }
}
