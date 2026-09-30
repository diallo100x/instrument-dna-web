# Instrument DNA — touch instrument / AUv3

An additive native iPhone/iPad app and embedded AUv3 music instrument. The existing web app remains unchanged. Pre-native baseline: `660dc2afa73c01faa8b8bfb5efffa27a6eb94f40`.

## Build and install

Requires a Mac with current Xcode and iOS/iPadOS 15.4 or later. Open `InstrumentDNA.xcodeproj`, choose the **InstrumentDNA** scheme (the containing app), select your signing team for both targets, then run on your device. Launch the app once. In an AUv3 host such as Logic Pro for iPad or AUM, add **Diallo Beats Audio Lab: Instrument DNA** as an instrument. Do not install/run the extension target by itself.

Unsigned simulator compile:

```sh
xcodebuild -project InstrumentDNA.xcodeproj -scheme InstrumentDNA -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

`python3 generate_project.py` regenerates the checked-in project. `./test.sh` runs portable DSP and project integrity checks. CI compiles both Apple targets. Device signing and distribution require the owner's Apple development account; no signed IPA is included.

## Playing and editing

- Piano, mallet, fretboard (six strings), or 4×4 drum-pad touch surface; simultaneous touches, octave selection and visible range.
- Independent finger slides bend each voice; Global mode bends all voices. Output tab provides global pitch and modulation wheels and bend range. MIDI includes channel pitch bend, CC1, sustain CC64, and independent member-channel MPE bends.
- Poly, mono, and last-held-note legato with glide; articulation selection and velocity trill controls; panic button.
- Dedicated tabs for all ten macros, both XY pads, Performance, Sources, DNA Edit, Anchors, Era and Output. Scrollable page contents and a tab menu remain accessible in small host windows.
- Host parameter automation and full-state recall. Standalone background audio is enabled. Named JSON Reflection and playable comparison export/import. Existing web comparisons retain per-articulation source samples. Native source import supports manual root-note and crop selection through AVAudioFile.
- Bottom-right branding: “a product of Diallo Beats Audio Lab”.

## Sound and compatibility limits

The native engine shares the web model **format**, not its complete DSP implementation. Original/sample modes retain imported waveform slices; reconstructed mode uses a compact harmonic approximation. Native sample playback currently couples pitch and duration. The web granular stretch algorithm and automatic note extraction have not been ported. Reflection-only presets contain no source audio and therefore use modeled synthesis. Missing articulation anchors fall back to sustain; they do not create measured new articulations.

All 29 exposed native controls affect playback. Era is a separate adjustable bandwidth foundation, not a complete historical recording simulator. Resonance is a simple tonal macro, not modal synthesis. Global attack/decay/release DNA offsets affect playback; other expert offsets are preserved as metadata until their DSP exists. Unsupported measurements are explicitly marked. No external recognition framework or historical audio is bundled.

Per-note bends are supported for local touch voices and MPE member channels. This first build does not implement MIDI 2.0 per-note messages, MPE pressure/timbre gestures, native analyzer training, full sample/noise slot routing or convolution. Mallet/fretboard/pad layouts currently address chromatic/model notes rather than implement separate percussion-kit mapping metadata.

## Verification status

Linux portable DSP tests pass with AddressSanitizer and UndefinedBehaviorSanitizer: audible finite output, pitch checks, independent/global bend, multi-voice separation, legato return priority, MPE, sustain, articulation samples and concurrent model replacement. LeakSanitizer is disabled because this environment disallows its process inspection. Project/plist/scheme integrity checks pass. Existing web suite: 33/33 passed.

.github/workflows/native-ios.yml also runs Apple AU integration tests for JSON/sample import, XY/Era and host state recall, and audible native rendering. These tests and the Apple simulator compile passed during implementation. The iPad simulator reached the playable interface with audio initialized; first-boot timing required a longer CI timeout.

Apple compilation is checked by `.github/workflows/native-ios.yml`; consult the latest Actions result. Real-device touch/audio latency, Bluetooth MIDI, AU host view resizing, parameter automation and session restoration require device/host acceptance testing before shipping. A simulator compile alone does not establish those behaviors.

## First device acceptance pass

1. Launch the containing app and play the default piano: sound should start without importing anything.
2. Import a web **playable comparison** from Files. Audition measured anchor keys in Hybrid Original before comparing reconstructed notes.
3. Hold two fingers in Per note slide mode; move one horizontally and check that the other stays in tune. In Global mode or with Global Bend, both voices should move.
4. Switch Piano/Mallet/Fretboard/Drum Pads, rotate the device, and reach every page using the All parameter tabs menu. Compact screens can scroll the playing controls horizontally.
5. Try Mono and Legato, an imported articulation layer, sustain pedal and Panic. Save a named playable comparison, reload it and verify Tone/Behavior XY, Era and performance controls.
6. Load the AUv3 inside your host; check host MIDI, automation, resizing and save/reopen of the host session. Confirm background audio in standalone use.

Report the model file, engine mode, iPad/iOS version and host used if a sound or mapping differs. Native reconstruction and time stretching are intentionally not yet at web-engine parity.
