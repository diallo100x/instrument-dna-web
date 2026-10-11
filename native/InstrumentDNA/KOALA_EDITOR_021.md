# Native AUv3 0.2.1 — editor startup compatibility

The 0.2.0 editor assigned preferredContentSize only after both view loading and audio-unit creation. Its queued attachment could also return early when the host had not loaded the view. Different host request ordering could therefore expose an empty, unsized editor. This is a concrete compatibility weakness, not a confirmed diagnosis of the reported Koala black screen.

0.2.1 sets its 720 × 540 preferred size during initialization and supplies an initial view frame. The factory hands audio-unit attachment and UI work to the main queue when necessary, explicitly loads the view, and installs the SwiftUI child with four edge constraints. A host that has not yet supplied audio sees a connection message. Reusing a controller with a new unit replaces its old interface. Nonnegative, finite host sizes with one automatic dimension are accepted.

The extension principal class, bundle IDs, AU type/subtype/manufacturer, parameter addresses, models and DSP stay stable. No additional App IDs are needed. Existing host state/presets remain compatible.

Verification:
- Portable DSP/project tests: passed.
- Web suite: 40/40 passed.
- Apple AU and native analyzer/articulation tests: passed.
- Both containing app and extension: Xcode simulator compile passed.
- Simulator editor startup, main/background factory ordering, replacement and 320 × 220 / 720 × 540 layout checks: passed.
- Apple workflow: https://github.com/diallo100x/instrument-dna-web/actions/runs/38113371495

A real Koala host pass remains required. This environment cannot operate the user's iPad/Koala or inspect its crash reports. If the patched build remains black, record the Koala and iPadOS versions, whether other AUv3 instruments open there, whether Instrument DNA still opens in Logic, and any InstrumentDNAInstrument crash entry under iPad Settings → Privacy & Security → Analytics & Improvements → Analytics Data.

Install from the native Xcode project: choose the InstrumentDNA containing-app scheme and the existing signing team, run on the iPad, then open the app once. Reopen Koala and test a fresh instance in a new song. This package contains source and requires Xcode signing; it is not an IPA.
