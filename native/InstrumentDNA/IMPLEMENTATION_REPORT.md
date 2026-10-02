# Instrument DNA native 0.1.0 — implementation report

## 1. Before the update

Web Instrument DNA v0.5.7 already provided analysis, sparse anchors, harmonic/hybrid and mallet playback, articulation layers, mono/legato, multi-source captures, named Reflections and playable comparisons, MIDI and waveform crop/zoom. Baseline `660dc2afa73c01faa8b8bfb5efffa27a6eb94f40` remains in history. No web source files were changed by the native addition.

## 2. Added

An iPhone/iPad standalone application and embedded AUv3 music instrument, sharing a C audio kernel and SwiftUI/UIKit touch interface. A checked-in Xcode project builds without third-party packages. Minimum deployment target is iOS/iPadOS 15.4.

## 3. Changed

Native code lives under `native/InstrumentDNA`; CI lives under `.github/workflows/native-ios.yml`. Standalone has its own internal component ID to avoid receiving an extension proxy. The extension retains `aumu / DbAL / InDN`. Initial activation waits until the instrument exists before resuming audio. Piano keys use fixed contrast colors. Branding reads **a product of Diallo Beats Audio Lab**.

## 4. Functional implementations

- Four switchable multitouch surfaces: Piano, Mallet, Fretboard and 4×4 Drum Pads.
- Independent touch-note bends plus global bend/modulation; octave and key-range selection.
- All 29 native parameters accessible through dedicated macro tabs and organized parameter pages; a tab menu and scrolling preserve access in smaller windows.
- Ten macros, two meaningful XY controls, output controls, poly/mono/legato with glide, articulation selection, velocity trill controls and Panic that silences struck voices too.
- Reflection/comparison import, named JSON export, retained articulation samples, manual source-note/crop import through AVAudioFile, and preservation of performance settings when adding an anchor.
- MIDI/MPE pitch input, sustain and modulation; standalone background audio; AU parameter exposure and complete host-state serialization.

DSP, import/recall and startup behavior have automated coverage. Physical touch gestures and integration with third-party AU hosts still require device acceptance testing.

## 5. Foundations and limitations

The native engine shares the Reflection format with the web app, but is not a full port of its analyzer or synthesis. Native source import assigns a root note manually. Automatic extraction and browser granular stretching remain in the web app. Native transposed samples currently couple pitch and length. Reconstructed notes use a compact harmonic approximation; exact imported anchors retain their recorded waveform.

Deep measurements, global/register/anchor data and unsupported fields are retained for extension. Global attack/decay/release offsets affect playback; other expert offsets are metadata. Missing articulation models fall back to sustain. Era is an adjustable recording-bandwidth foundation, not a complete historical recorder model. Multiple noise/exciter routing and full modal synthesis remain future work. Pads currently map chromatic/model pitches; there is no separate GM drum-kit map editor. MPE pressure/timbre and MIDI 2.0 are not implemented.

## 6. Testing and results

- Existing web suite: **33/33 passed**.
- Portable DSP with AddressSanitizer and UndefinedBehaviorSanitizer: **passed**. Covers audible finite output, fundamental pitch, independent/global bending, polyphonic separation, mono/legato priority, MPE, sustain, articulation samples, concurrent model replacement and struck-note Panic.
- Project/plist/scheme integrity: **passed**.
- Apple AU integration: **passed**. Imports a sample-bearing comparison; checks 29 parameters, macros/XY/Era, host state recall and audible native AU rendering.
- Xcode simulator compile of both containing app and embedded extension: **passed**.
- Simulator: **passed**, including the audio-ready marker and application survival check. Full interface and final piano contrast were inspected in screenshots. A five-minute first-boot timeout was extended to ten minutes.
- Latest workflow: https://github.com/diallo100x/instrument-dna-web/actions/runs/36653777860

LeakSanitizer was unavailable in the Linux environment; it was explicitly disabled. No real iPad or external AU host was operated from this environment.

## 7. Known issues / acceptance still required

This is source for a test build, not a signed IPA. Device installation needs Xcode and the owner's signing team. Real-device latency, multitouch playing, background/session interruptions, Bluetooth/external MIDI, AU resizing/automation and host save/reopen must be tested on the owner's setup. Parameter ramp events currently apply their target immediately; dedicated ramp smoothing is pending. Native reconstruction/time stretching does not yet match the web engine. An internal simulator AVAudioEngine session-association warning (-10879) was observed despite successful startup; real-device audio output remains an acceptance check.

## 8. Incremental commits

| Commit | Change |
| --- | --- |
| f6a440d | Add native Instrument DNA DSP and portable regression tests |
| 9ee5918 | Add iOS standalone and AUv3 touch instrument with parameter tabs |
| a592592 | Fix Swift numeric literals found by Apple build verification |
| c485623 | Verify iPad simulator startup and correct CoreMIDI packet pointer |
| 7bc32e1 | Add Apple AU model import, state recall and audio rendering tests |
| 0d62c69 | Enable background audio and keep touch controls accessible on compact screens |
| 3c563c7 | Guard initial audio startup and capture simulator diagnostics |
| f96f412 | Ad hoc sign simulator bundles before Apple Silicon launch |
| 85916e4 | Keep standalone instrument local and verify audio-ready startup |
| f49b2b9 | Use iOS-compatible instantiation for the local instrument component |
| 8e508e7 | Preserve performance settings and model names when adding anchors |
| e35aef7 | Silence ringing mallet voices on Panic with regression coverage |
| c707908 | Improve piano key contrast and allow simulator first-boot time |

## 9. Repository and branch

Pushed to `diallo100x/instrument-dna-web`, branch `main`. Local source is synchronized to the remote before handoff. Download the repository, open `native/InstrumentDNA/InstrumentDNA.xcodeproj`, choose the **InstrumentDNA** containing-app scheme, set the signing team for both targets, and run on the iPad. Then add the instrument in the AU host. Do not directly install the extension.

## 10. Next milestone

Run the README's device acceptance checklist with the saved Pifano playable comparison in standalone and an AU host. Then port the web engine's independent pitch/time stretching and analyzer workflow to native, with A/B sound comparisons against the existing web instruments.

## Native module/extraction update — October 2, 2026

The preceding report describes the original native foundation. This update preserves that code and the existing web app, adding:

- A page for each existing web module, side previous/next arrows with wraparound, a direct Module picker, and a musical macro overview. Existing dedicated parameter pages and touch surfaces remain available.
- Native monophonic extraction from AVAudioFile-decoded crops, basic periodicity confidence and harmonic measurements, sustained/plucked/struck profiles, and sparse 1/3/6/12 anchors per octave. New anchors map to detected MIDI keys and can be saved in existing Reflection/comparison formats.
- A note review page with isolated source-slice and reconstructed-note auditions, immediate stop, three-second preview limit, and non-destructive articulation-layer copying. Source slices bypass instrument pitch/shaping; master output gain/limiting remains active. Copy collisions protect existing destination sounds.
- Explicit AU custom-editor discovery, compact/expanded/default-size negotiation, controller lifecycle attachment and note cleanup when closing the editor. These are compatibility improvements; the reported Koala issue has not been reproduced or certified resolved here.

Fully operational foundations are covered by automated tests: native pitch detection/silence rejection, sparse versus chromatic capture, mapping/audio preservation, layer collisions, JSON round trips, source preview isolation from mono/legato and global pitch, stop/panic, and existing DSP behavior. All 33 web tests pass. Apple AU integration tests, native Swift model/analyzer tests, and iOS app/extension compilation passed in [Actions run 36954228203](https://github.com/diallo100x/instrument-dna-web/actions/runs/36954228203). Simulator startup is checked by the same workflow; consult its final result.

Known limits: extraction is monophonic (approximately 65–1800 Hz), selects one stable occurrence per measured key, and does not identify instruments, trills or source-separated chord notes. Basic harmonic/attack estimates are approximate; modal, noise-spectrum and recognition measurements remain unsupported. Native source crop uses numeric bounds, maximum 15 seconds, configured before choosing a file. The native UI does not yet expose the web waveform/zoom editor, every unused detected candidate, destructive retagging/removal, independent stretch or full web DSP parity. Layer copying retains the original mapping; it does not convert a sustained performance into a real trill. Real Koala host loading and physical iPad audio/MIDI/gesture acceptance remain unverified. No signed device IPA/TestFlight distribution is created.

Incremental commits pushed to `diallo100x/instrument-dna-web`, `main`:

- `ca1e0ca` — resizable editor and dedicated audition voices.
- `ee25239` — native extraction, module navigation and articulation review.
- `6564e97` — CoreAudioKit linking and host-default sizes.
- `0f9fdfe` — correct AU editor-discovery API; Apple checks pass.

Next milestone: native source waveform/crop audition and full candidate review (enable/disable, key correction, articulation move), followed by real Koala acceptance and independent time stretching. Downloadable deliverable remains the containing-app Xcode project, not a standalone installable iPad archive.
