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

struct Transform: Codable {
    static let name = Localization(english: "Transform", japanese: "トランスフォーム")
    
    let translation: CGPoint, scale: CGPoint, rotation: CGFloat
    let z: CGFloat, affineTransform: CGAffineTransform
    
    init(translation: CGPoint = CGPoint(), z: CGFloat = 0, rotation: CGFloat = 0) {
        let pow2 = pow(2, z)
        self.translation = translation
        self.scale = CGPoint(x: pow2, y: pow2)
        self.z = z
        self.rotation = rotation
        self.affineTransform = Transform.affineTransform(translation: translation,
                                                         scale: scale, rotation: rotation)
    }
    init(translation: CGPoint = CGPoint(), scale: CGPoint, rotation: CGFloat = 0) {
        self.translation = translation
        self.z = log2(scale.x)
        self.scale = scale
        self.rotation = rotation
        self.affineTransform = Transform.affineTransform(translation: translation,
                                                         scale: scale, rotation: rotation)
    }
    init(translation: CGPoint, z: CGFloat, scale: CGPoint, rotation: CGFloat) {
        self.translation = translation
        self.z = z
        self.scale = scale
        self.rotation = rotation
        self.affineTransform = Transform.affineTransform(translation: translation,
                                                         scale: scale, rotation: rotation)
    }
    
    private static func affineTransform(translation: CGPoint,
                                        scale: CGPoint, rotation: CGFloat) -> CGAffineTransform {
        var affine = CGAffineTransform(translationX: translation.x, y: translation.y)
        if rotation != 0 {
            affine = affine.rotated(by: rotation)
        }
        if scale != CGPoint() {
            affine = affine.scaledBy(x: scale.x, y: scale.y)
        }
        return affine
    }
    
    func with(translation: CGPoint) -> Transform {
        return Transform(translation: translation, z: z, scale: scale, rotation: rotation)
    }
    func with(z: CGFloat) -> Transform {
        return Transform(translation: translation, z: z, rotation: rotation)
    }
    func with(scale: CGFloat) -> Transform {
        return Transform(translation: translation,
                         scale: CGPoint(x: scale, y: scale), rotation: rotation)
    }
    func with(scale: CGPoint) -> Transform {
        return Transform(translation: translation,
                         scale: scale, rotation: rotation)
    }
    func with(rotation: CGFloat) -> Transform {
        return Transform(translation: translation,
                         z: z, scale: scale, rotation: rotation)
    }
    
    var isIdentity: Bool {
        return translation == CGPoint() && scale == CGPoint(x: 1, y: 1) && rotation == 0
    }
}
extension Transform: Equatable {
    static func ==(lhs: Transform, rhs: Transform) -> Bool {
        return lhs.translation == rhs.translation
            && lhs.scale == rhs.scale && lhs.rotation == rhs.rotation
    }
}
extension Transform: Interpolatable {
    static func linear(_ f0: Transform, _ f1: Transform, t: CGFloat) -> Transform {
        let translation = CGPoint.linear(f0.translation, f1.translation, t: t)
        let scaleX = CGFloat.linear(f0.scale.x, f1.scale.x, t: t)
        let scaleY = CGFloat.linear(f0.scale.y, f1.scale.y, t: t)
        let rotation = CGFloat.linear(f0.rotation, f1.rotation, t: t)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func firstMonospline(_ f1: Transform, _ f2: Transform, _ f3: Transform,
                                with msx: MonosplineX) -> Transform {
        let translation = CGPoint.firstMonospline(f1.translation, f2.translation,
                                                  f3.translation, with: msx)
        let scaleX = CGFloat.firstMonospline(f1.scale.x, f2.scale.x, f3.scale.x, with: msx)
        let scaleY = CGFloat.firstMonospline(f1.scale.y, f2.scale.y, f3.scale.y, with: msx)
        let rotation = CGFloat.firstMonospline(f1.rotation, f2.rotation, f3.rotation, with: msx)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func monospline(_ f0: Transform, _ f1: Transform, _ f2: Transform, _ f3: Transform,
                           with msx: MonosplineX) -> Transform {
        let translation = CGPoint.monospline(f0.translation, f1.translation,
                                             f2.translation, f3.translation, with: msx)
        let scaleX = CGFloat.monospline(f0.scale.x, f1.scale.x,
                                        f2.scale.x, f3.scale.x, with: msx)
        let scaleY = CGFloat.monospline(f0.scale.y, f1.scale.y,
                                        f2.scale.y, f3.scale.y, with: msx)
        let rotation = CGFloat.monospline(f0.rotation, f1.rotation,
                                          f2.rotation, f3.rotation, with: msx)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
    static func endMonospline(_ f0: Transform, _ f1: Transform, _ f2: Transform,
                              with msx: MonosplineX) -> Transform {
        
        let translation = CGPoint.endMonospline(f0.translation, f1.translation,
                                                f2.translation, with: msx)
        let scaleX = CGFloat.endMonospline(f0.scale.x, f1.scale.x, f2.scale.x, with: msx)
        let scaleY = CGFloat.endMonospline(f0.scale.y, f1.scale.y, f2.scale.y, with: msx)
        let rotation = CGFloat.endMonospline(f0.rotation, f1.rotation, f2.rotation, with: msx)
        return Transform(translation: translation,
                         scale: CGPoint(x: scaleX, y: scaleY), rotation: rotation)
    }
}

typealias Hz = CGFloat
struct Wiggle: Codable {
    var amplitude = CGPoint(), frequency = Hz(8)
    
    func with(amplitude: CGPoint) -> Wiggle {
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    func with(frequency: Hz) -> Wiggle {
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    
    var isEmpty: Bool {
        return amplitude == CGPoint()
    }
    func phasePosition(with position: CGPoint, phase: CGFloat) -> CGPoint {
        let x = sin(2 * (.pi) * phase)
        return CGPoint(x: position.x + amplitude.x * x, y: position.y + amplitude.y * x)
    }
}
extension Wiggle: Equatable {
    static func ==(lhs: Wiggle, rhs: Wiggle) -> Bool {
        return lhs.amplitude == rhs.amplitude && lhs.frequency == rhs.frequency
    }
}
extension Wiggle: Interpolatable {
    static func linear(_ f0: Wiggle, _ f1: Wiggle, t: CGFloat) -> Wiggle {
        let amplitude = CGPoint.linear(f0.amplitude, f1.amplitude, t: t)
        let frequency = CGFloat.linear(f0.frequency, f1.frequency, t: t)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func firstMonospline(_ f1: Wiggle, _ f2: Wiggle,
                                _ f3: Wiggle, with msx: MonosplineX) -> Wiggle {
        let amplitude = CGPoint.firstMonospline(f1.amplitude, f2.amplitude, f3.amplitude, with: msx)
        let frequency = CGFloat.firstMonospline(f1.frequency, f2.frequency, f3.frequency, with: msx)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func monospline(_ f0: Wiggle, _ f1: Wiggle,
                           _ f2: Wiggle, _ f3: Wiggle, with msx: MonosplineX) -> Wiggle {
        let amplitude = CGPoint.monospline(f0.amplitude, f1.amplitude,
                                           f2.amplitude, f3.amplitude, with: msx)
        let frequency = CGFloat.monospline(f0.frequency, f1.frequency,
                                           f2.frequency, f3.frequency, with: msx)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
    static func endMonospline(_ f0: Wiggle, _ f1: Wiggle,
                              _ f2: Wiggle, with msx: MonosplineX) -> Wiggle {
        let amplitude = CGPoint.endMonospline(f0.amplitude, f1.amplitude, f2.amplitude, with: msx)
        let frequency = CGFloat.endMonospline(f0.frequency, f1.frequency, f2.frequency, with: msx)
        return Wiggle(amplitude: amplitude, frequency: frequency)
    }
}
extension Wiggle: Referenceable {
    static let name = Localization(english: "Wiggle", japanese: "振動")
}


