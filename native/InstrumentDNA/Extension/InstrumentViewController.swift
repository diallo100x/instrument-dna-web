import UIKit
import SwiftUI
import CoreAudioKit
import AudioToolbox

final class InstrumentViewController:AUViewController,AUAudioUnitFactory {
    private var unit:DNAudioUnit?
    private var hosting:UIHostingController<InstrumentView>?
    override func loadView(){view=UIView();view.backgroundColor=UIColor(red:.06,green:.1,blue:.12,alpha:1);installInterface()}
    func createAudioUnit(with componentDescription:AudioComponentDescription)throws->AUAudioUnit {
        let created=try DNAudioUnit(componentDescription:componentDescription,options:[]);unit=created
        DispatchQueue.main.async{[weak self] in self?.installInterface()};return created
    }
    private func installInterface(){guard isViewLoaded,let unit=unit,hosting==nil else{return};let controller=UIHostingController(rootView:InstrumentView(model:InstrumentModel(unit:unit)));hosting=controller;addChild(controller);controller.view.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(controller.view);NSLayoutConstraint.activate([controller.view.topAnchor.constraint(equalTo:view.topAnchor),controller.view.bottomAnchor.constraint(equalTo:view.bottomAnchor),controller.view.leadingAnchor.constraint(equalTo:view.leadingAnchor),controller.view.trailingAnchor.constraint(equalTo:view.trailingAnchor)]);controller.didMove(toParent:self);preferredContentSize=CGSize(width:900,height:650)}
}
