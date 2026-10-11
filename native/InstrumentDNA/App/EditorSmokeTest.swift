#if DEBUG
import UIKit
import AudioToolbox

enum EditorSmokeTest {
    static func run() {
        precondition(Thread.isMainThread)
        PhysicalFitSmokeTest.run()
        let description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x496e444e, componentManufacturer: 0x4462414c,
            componentFlags: 0, componentFlagsMask: 0)
        let first = InstrumentEditorController()
        precondition(first.preferredContentSize == CGSize(width:720,height:540))
        first.loadViewIfNeeded() // View requested before audio factory.
        precondition(first.children.isEmpty && !first.view.subviews.isEmpty)
        _ = try! first.createAudioUnit(with: description)
        check(first)
        let second = InstrumentEditorController()
        _ = try! second.createAudioUnit(with: description) // Audio requested before view.
        check(second)
        // Hosts may reuse a controller to create a replacement unit.
        _ = try! second.createAudioUnit(with: description)
        precondition(second.children.count == 1)
        let third = InstrumentEditorController()
        third.loadViewIfNeeded()
        DispatchQueue.global().async {
            _ = try! third.createAudioUnit(with: description)
            DispatchQueue.main.async {
                check(third)
                fputs("INSTRUMENT_DNA_EDITOR_TESTS_PASSED\n",stdout);fflush(stdout)
            }
        }
    }
    private static func check(_ editor: InstrumentEditorController) {
        precondition(editor.children.count == 1)
        for size in [CGSize(width:320,height:220),CGSize(width:720,height:540)] {
            editor.view.frame = CGRect(origin:.zero,size:size)
            editor.view.layoutIfNeeded()
            precondition(editor.children[0].view.bounds.size == size)
            precondition(editor.children[0].view.isOpaque)
        }
    }
}
#endif
