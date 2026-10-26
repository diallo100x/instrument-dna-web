import AppKit
import SwiftUI
import CoreAudioKit
import AudioToolbox

class InstrumentEditorController: AUViewController, AUAudioUnitFactory {
    private var unit: DNAudioUnit?
    private var hosting: NSHostingController<InstrumentView>?
    override func loadView() {
        preferredContentSize = NSSize(width:900,height:700)
        let root = NSView(frame:NSRect(origin:.zero,size:preferredContentSize))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed:0.06,green:0.1,blue:0.12,alpha:1).cgColor
        view = root
    }
    override func viewDidLoad() {super.viewDidLoad();installInterface()}
    override func viewWillDisappear() {unit?.panic();super.viewWillDisappear()}
    func createAudioUnit(with description:AudioComponentDescription) throws -> AUAudioUnit {
        let created = try DNAudioUnit(componentDescription:description,options:[])
        if Thread.isMainThread {attach(created)}
        else {DispatchQueue.main.async{[weak self] in self?.attach(created)}}
        return created
    }
    private func attach(_ created:DNAudioUnit) {
        dispatchPrecondition(condition:.onQueue(.main))
        if unit !== created, let previous=hosting {
            previous.view.removeFromSuperview();previous.removeFromParent();hosting=nil
        }
        unit=created
        _ = view
        installInterface()
    }
    private func installInterface() {
        guard isViewLoaded, let unit=unit, hosting==nil else{return}
        let controller=NSHostingController(rootView:InstrumentView(model:InstrumentModel(unit:unit)))
        addChild(controller)
        // AU hosts may resize a detached editor before placing it in a window.
        // AppKit autoresizing keeps the hosted view in sync immediately.
        controller.view.frame=view.bounds
        controller.view.autoresizingMask=[.width,.height]
        view.addSubview(controller.view)
        hosting=controller
    }
}
