import UIKit
import SwiftUI
import CoreAudioKit
import AudioToolbox

// Shared implementation so simulator tests exercise the same editor as the extension.
class InstrumentEditorController: AUViewController, AUAudioUnitFactory {
    private var unit: DNAudioUnit?
    private var hosting: UIHostingController<InstrumentView>?
    private let startup = UILabel()
    private static let initialSize = CGSize(width: 720, height: 540)

    override init(nibName: String? = nil, bundle: Bundle? = nil) {
        super.init(nibName: nibName, bundle: bundle)
        preferredContentSize = Self.initialSize
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        preferredContentSize = Self.initialSize
    }
    override func loadView() {
        let root = UIView(frame: CGRect(origin: .zero, size: Self.initialSize))
        root.backgroundColor = UIColor(red: 0.06, green: 0.1, blue: 0.12, alpha: 1)
        view = root
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        startup.text = "Instrument DNA · connecting to host audio…"
        startup.textColor = .white
        startup.numberOfLines = 0
        startup.textAlignment = .center
        startup.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startup)
        NSLayoutConstraint.activate([
            startup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            startup.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            startup.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        installInterface()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installInterface()
    }
    override func viewWillDisappear(_ animated: Bool) {
        unit?.panic()
        super.viewWillDisappear(animated)
    }
    func createAudioUnit(with description: AudioComponentDescription) throws -> AUAudioUnit {
        let created = try DNAudioUnit(componentDescription: description, options: [])
        // Hosts may invoke the factory off the main queue. Never construct SwiftUI
        // or mutate UIKit/controller state from that callback thread.
        if Thread.isMainThread { attach(created) }
        else { DispatchQueue.main.async { [weak self] in self?.attach(created) } }
        return created
    }
    private func attach(_ created: DNAudioUnit) {
        dispatchPrecondition(condition: .onQueue(.main))
        if unit !== created, let previous = hosting {
            previous.willMove(toParent: nil)
            previous.view.removeFromSuperview()
            previous.removeFromParent()
            hosting = nil
        }
        unit = created
        loadViewIfNeeded()
        installInterface()
    }
    private func installInterface() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isViewLoaded, let unit = unit, hosting == nil else { return }
        let controller = UIHostingController(rootView: InstrumentView(model: InstrumentModel(unit: unit)))
        controller.view.backgroundColor = view.backgroundColor
        controller.view.isOpaque = true
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(controller)
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        controller.didMove(toParent: self)
        hosting = controller
        startup.isHidden = true
        view.setNeedsLayout()
    }
}
