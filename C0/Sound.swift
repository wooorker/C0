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
import QuartzCore

struct Sound {
    var url: URL? {
        didSet {
            if let url = url {
                self.bookmark = try? url.bookmarkData()
                self.name = url.lastPathComponent
            }
        }
    }
    private var bookmark: Data?
    var name = ""
    var volume = 1.0
    var isHidden = false
    
    private enum CodingKeys: String, CodingKey {
        case bookmark, name,volume, isHidden
    }
}
extension Sound: Equatable {
    static func ==(lhs: Sound, rhs: Sound) -> Bool {
        return lhs.url == rhs.url && lhs.name == rhs.name
            && lhs.volume == rhs.volume && lhs.isHidden == rhs.isHidden
    }
}
extension Sound: Codable {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bookmark = try values.decode(Data.self, forKey: .bookmark)
        name = try values.decode(String.self, forKey: .name)
        volume = try values.decode(Double.self, forKey: .volume)
        isHidden = try values.decode(Bool.self, forKey: .isHidden)
        url = URL(bookmark: bookmark)
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookmark, forKey: .bookmark)
        try container.encode(name, forKey: .name)
        try container.encode(volume, forKey: .volume)
        try container.encode(isHidden, forKey: .isHidden)
    }
}
extension Sound: Referenceable {
    static let name = Localization(english: "Sound", japanese: "サウンド")
}

final class SoundEditor: LayerRespondable, Localizable {
    static let name = Localization(english: "Sound Editor", japanese: "サウンドエディタ")
    
    weak var parent: Respondable?
    var children = [Respondable]() {
        didSet {
            update(withChildren: children, oldChildren: oldValue)
        }
    }
    
    var locale = Locale.current {
        didSet {
            updateLayout()
        }
    }
    
    let nameLabel = Label(text: Localization(english: "Sound", japanese: "サウンド"), font: .bold)
    let soundLabel = Label(text: Localization(english: "Empty", japanese: "空"))
    let layer = CALayer.interface()
    init() {
        layer.masksToBounds = true
        soundLabel.defaultBorderColor = Color.border.cgColor
        children = [nameLabel, soundLabel]
        update(withChildren: children, oldChildren: [])
        updateLayout()
    }
    
    var sound = Sound() {
        didSet {
            soundLabel.localization = sound.url != nil ?
                Localization(sound.name) : Localization(english: "Empty", japanese: "空")
        }
    }
    
    var frame: CGRect {
        get {
            return layer.frame
        }
        set {
            layer.frame = newValue
            updateLayout()
        }
    }
    func updateLayout() {
        _ = Layout.leftAlignment([nameLabel, Padding(), soundLabel], height: frame.height)
    }
    
    var disabledRegisterUndo = false
    
    struct HandlerObject {
        let soundEditor: SoundEditor, sound: Sound, oldSound: Sound, type: Action.SendType
    }
    var setSoundHandler: ((HandlerObject) -> ())?
    
    func delete(with event: KeyInputEvent) {
        if sound.url != nil {
            set(Sound(), old: self.sound)
        }
    }
    func copy(with event: KeyInputEvent) -> CopiedObject {
        guard let url = sound.url else {
            return CopiedObject(objects: [sound])
        }
        return CopiedObject(objects: [sound, url])
    }
    func paste(_ copiedObject: CopiedObject, with event: KeyInputEvent) {
        for object in copiedObject.objects {
            if let url = object as? URL, url.isConforms(uti: kUTTypeAudio as String) {
                var sound = Sound()
                sound.url = url
                set(sound, old: self.sound)
                return
            } else if let sound = object as? Sound {
                set(sound, old: self.sound)
                return
            }
        }
    }
    func set(_ sound: Sound, old oldSound: Sound) {
        registeringUndoManager?.registerUndo(withTarget: self) { $0.set(oldSound, old: sound) }
        setSoundHandler?(HandlerObject(soundEditor: self,
                                       sound: oldSound, oldSound: oldSound, type: .begin))
        self.sound = sound
        setSoundHandler?(HandlerObject(soundEditor: self,
                                       sound: sound, oldSound: oldSound, type: .end))
    }
}
