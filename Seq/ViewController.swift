//
//  ViewController.swift
//  Seq
//
//  Created by Viktor on 2018-07-03.
//  Copyright © 2018 Viktor Fröberg. All rights reserved.
//

import UIKit
import AudioKit

let COLUMNS = 4
let ROWS = 4
let TOTAL_PADS = COLUMNS * ROWS
let SPACING = 6
let BPM = 100.0
let SEQUENCE_BEATS = AKDuration(beats: 4.0)

extension Array {
    func get(index: Int) -> Element? {
        return index < count ? self[index] : nil
    }
}

public struct MIDINote {
    public let noteNumber: MIDINoteNumber
    public let velocity: MIDIVelocity
}

public struct MIDIStep {
    public let notes : [MIDINote]
}

public struct MIDITrack {
    public let steps : [MIDIStep]
}

extension UIColor {
    static func fromHexString(hex: String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return UIColor.gray
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

let RED = UIColor.fromHexString(hex: "#f14337")
let PINK = UIColor.fromHexString(hex: "#e91e62")
let PURPLE = UIColor.fromHexString(hex: "#9c27b0")
let DEEP_PURPLE = UIColor.fromHexString(hex: "#673ab7")
let INDIGO = UIColor.fromHexString(hex: "#3f51b5")
let BLUE = UIColor.fromHexString(hex: "#3f96f3")
let LIGHT_BLUE = UIColor.fromHexString(hex: "#45a9f5")
let CYAN = UIColor.fromHexString(hex: "#4abcd4")
let TEAL = UIColor.fromHexString(hex: "#379687")
let GREEN = UIColor.fromHexString(hex: "#4caf50")
let LIGHT_GREEN = UIColor.fromHexString(hex: "#8bc34a")
let LIME = UIColor.fromHexString(hex: "#cddd38")
let YELLOW = UIColor.fromHexString(hex: "#fbec3b")
let AMBER = UIColor.fromHexString(hex: "#f7c10a")
let ORANGE = UIColor.fromHexString(hex: "#f49803")
let DEEP_ORANGE = UIColor.fromHexString(hex: "#f15723")

public struct Pad {
    public let color: UIColor
}

let PADS = [
    Pad(color: RED),
    Pad(color: PINK),
    Pad(color: PURPLE),
    Pad(color: DEEP_PURPLE),
    Pad(color: INDIGO),
    Pad(color: BLUE),
    Pad(color: LIGHT_BLUE),
    Pad(color: CYAN),
    Pad(color: TEAL),
    Pad(color: GREEN),
    Pad(color: LIGHT_GREEN),
    Pad(color: LIME),
    Pad(color: YELLOW),
    Pad(color: AMBER),
    Pad(color: ORANGE),
    Pad(color: DEEP_ORANGE),
]

class MIDISequencer {
    let midi = AudioKit.midi
    let sequencer = AKSequencer()
    
    public init(tracks: [MIDITrack]) {
        self.midi.openOutput()
        
        for trackIndex in 0...(TOTAL_PADS - 1) {
            let track = self.sequencer.newTrack()
            let callbackInstrument = AKCallbackInstrument {event, noteNumber, velocity in
                if event == .noteOn {
                    self.midi.sendNoteOnMessage(noteNumber: noteNumber, velocity: velocity, channel: MIDIChannel(trackIndex))
                }
                else if event == .noteOff {
                    self.midi.sendNoteOffMessage(noteNumber: noteNumber, velocity: velocity, channel: MIDIChannel(trackIndex))
                }
            }
            track?.setMIDIOutput(callbackInstrument.midiIn)
        }
        
        self.updateTracks(tracks: tracks)
        
        self.sequencer.setLength(AKDuration(beats: Double(TOTAL_PADS) * 0.25))
        self.sequencer.setTempo(BPM)
        self.sequencer.enableLooping()
    }
    
    func play() {
        self.sequencer.play()
    }
    
    func stop() {
        self.sequencer.stop()
        self.sequencer.rewind()
    }
    
    func pause() {
        self.sequencer.stop()
    }
    
    func updateTracks(tracks: [MIDITrack]) {
        for (trackIndex, track) in self.sequencer.tracks.enumerated() {
            track.clear()
            if let midiTrack = tracks.get(index: trackIndex) {
                for (stepIndex, step) in midiTrack.steps.enumerated() {
                    if (step.notes.count > 0) {
                        let position = Double(stepIndex) / 4.0
                        for note in step.notes {
                            track.add(noteNumber: note.noteNumber, velocity: note.velocity, position: AKDuration(beats: position), duration: AKDuration(beats: 0.25))
                        }
                    }
                }
            }
        }
    }
    
    deinit {
        self.sequencer.stop()
    }
}

class ViewController: UIViewController {
    var sequencer = MIDISequencer(tracks: [])
    var pads = [Int:Bool]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        self.title = "Tracks"
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let totalSpaceWidth = SPACING * (COLUMNS + 1)
        let totalColumnWidth = screenWidth - CGFloat(totalSpaceWidth)
        let columnWidth = Int(totalColumnWidth / CGFloat(COLUMNS))
        for rowIndex in 0...(ROWS - 1) {
            for columnIndex in 0...(COLUMNS - 1) {
                let padIndex = (rowIndex * COLUMNS) + columnIndex
                let spacingX = SPACING * (columnIndex + 1)
                let spacingY = SPACING * (rowIndex + 1)
                let view = UIControl.init(frame: CGRect(x: columnIndex * columnWidth + spacingX, y: rowIndex * columnWidth + spacingY + Int(statusBarHeight), width: columnWidth, height: columnWidth))
                view.tag = padIndex
                view.addTarget(self, action: #selector(self.buttonClicked), for: .touchUpInside)
                view.backgroundColor = PADS.get(index: padIndex)!.color
                self.pads.updateValue(false, forKey: padIndex)
                self.view.addSubview(view)
            }
        }
    }
    
    func play() {
        let padIndexes = 0...(TOTAL_PADS - 1)
        let tracks = padIndexes.map { (trackIndex) -> MIDITrack in
            let steps = padIndexes.map { (stepIndex) -> MIDIStep in
                if (self.pads[stepIndex]! == false) {
                    return MIDIStep(notes: [])
                } else {
                    return MIDIStep(notes: [MIDINote(noteNumber: 67, velocity: 127)])
                }
            }
            return MIDITrack(steps: steps)
        }
        self.sequencer.updateTracks(tracks: tracks)
    }
    
    @objc func buttonClicked (sender: UIControl) {
        let trackViewController = TrackViewController(index: sender.tag, pad: PADS.get(index: sender.tag)!) { (index) in
            print("Pad pressed")
        }
        self.navigationController?.pushViewController(trackViewController, animated: true)
//        if (self.pads[sender.tag]! == false) {
//            self.pads.updateValue(true, forKey: sender.tag)
//            sender.backgroundColor = UIColor.green
//        } else {
//            self.pads.updateValue(false, forKey: sender.tag)
//            sender.backgroundColor = UIColor.red
//        }
//        self.play()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

class TrackViewController: UIViewController {
    let index: Int
    let pad: Pad
    var pads = [Int:Bool]()
    let onPressPad: (_ index: Int) -> ()
    
    init(index: Int, pad: Pad, onPressPad: @escaping (_ index: Int) -> ()) {
        self.index = index
        self.pad = pad
        self.onPressPad = onPressPad
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = self.pad.color
        self.title = "Track \(index + 1)"
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let totalSpaceWidth = SPACING * (COLUMNS + 1)
        let totalColumnWidth = screenWidth - CGFloat(totalSpaceWidth)
        let columnWidth = Int(totalColumnWidth / CGFloat(COLUMNS))
        for rowIndex in 0...(ROWS - 1) {
            for columnIndex in 0...(COLUMNS - 1) {
                let padIndex = (rowIndex * COLUMNS) + columnIndex
                let spacingX = SPACING * (columnIndex + 1)
                let spacingY = SPACING * (rowIndex + 1)
                let view = UIControl.init(frame: CGRect(x: columnIndex * columnWidth + spacingX, y: rowIndex * columnWidth + spacingY + Int(statusBarHeight), width: columnWidth, height: columnWidth))
                view.tag = padIndex
                view.addTarget(self, action: #selector(self.buttonClicked), for: .touchUpInside)
                view.backgroundColor = UIColor.fromHexString(hex: "#7685ab")
                self.pads.updateValue(false, forKey: padIndex)
                self.view.addSubview(view)
            }
        }
    }
    
    @objc func buttonClicked (sender: UIControl) {
        self.onPressPad(self.index)
        if (self.pads[sender.tag]! == false) {
            self.pads.updateValue(true, forKey: sender.tag)
            sender.backgroundColor = UIColor.fromHexString(hex: "#32466f")
        } else {
            self.pads.updateValue(false, forKey: sender.tag)
            sender.backgroundColor = UIColor.fromHexString(hex: "#7685ab")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.statusBarStyle = .lightContent
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
