/*
 Copyright 2018 S
 
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

/**
 # Issue
 - リファレンス表示の具体化
 */
final class ReferenceEditor: Layer, Respondable {
    static let name = Localization(english: "Reference Editor", japanese: "情報エディタ")
    static let feature = Localization(english: "Close: Move cursor to outside",
                                      japanese: "閉じる: カーソルを外に出す")
    
    var reference: Referenceable? {
        didSet {
            updateWithReference()
        }
    }
    
    let minWidth = 200.0.cf
    
    init(reference: Referenceable? = nil) {
        self.reference = reference
        super.init()
        fillColor = .background
        updateWithReference()
    }
    
    private func updateWithReference() {
        if let reference = reference {
            let cas = ReferenceEditor.childrenAndSize(with: reference, width: minWidth)
            replace(children: cas.children)
            frame = CGRect(x: frame.origin.x, y: frame.origin.y - (cas.size.height - frame.height),
                           width: cas.size.width, height: cas.size.height)
        } else {
            replace(children: [])
        }
    }
    private static func childrenAndSize(with reference: Referenceable,
                                        width: CGFloat) -> (children: [Layer], size: CGSize) {
        
        let type =  Swift.type(of: reference).name, feature = Swift.type(of: reference).feature
        let instanceDescription = reference.instanceDescription
        let description: Localization
        if instanceDescription.isEmpty && feature.isEmpty {
            description = Localization(english: "No description", japanese: "説明なし")
        } else {
            description = !instanceDescription.isEmpty && !feature.isEmpty ?
                instanceDescription + Localization("\n\n") + feature : instanceDescription + feature
        }
        
        let typeLabel = Label(frame: CGRect(x: 0, y: 0, width: width, height: 0),
                              text: type, font: .hedding0)
        let descriptionLabel = Label(frame: CGRect(x: 0, y: 0, width: width, height: 0),
                                     text: description)
        let padding = Layout.basicPadding
        let size = CGSize(width: width + padding * 2,
                          height: typeLabel.frame.height + descriptionLabel.frame.height + padding * 5)
        var y = size.height - typeLabel.frame.height - padding * 2
        typeLabel.frame.origin = CGPoint(x: padding, y: y)
        y -= descriptionLabel.frame.height + padding
        descriptionLabel.frame.origin = CGPoint(x: padding, y: y)
        return ([typeLabel, descriptionLabel], size)
    }
}
