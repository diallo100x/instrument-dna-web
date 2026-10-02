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
- Each web module has a native page: Reference, Detected note slices, Instrument map, Performance/articulation layers, Main/musical controls and Era DNA. Side ‹/› arrows cycle through modules, with a direct Module picker. Dedicated macro, XY, DNA Edit and Output pages remain available; compact windows scroll their contents.
- Host parameter automation and full-state recall. Standalone background audio is enabled. Named JSON Reflection and playable comparison export/import. Existing web comparisons retain per-articulation source samples. Native source import uses AVAudioFile. Set the crop (maximum 15 seconds), profile, capture density and articulation on Reference before choosing a file. Automatic monophonic extraction maps stable pitches; disable it for manual root assignment.
- Bottom-right branding: “a product of Diallo Beats Audio Lab”.

## Native extraction and note review

Reference offers Sustained, Plucked/string and Struck/mallet profiles with 1/3/6/12 anchors per octave. Analysis is limited to approximately 65–1800 Hz, selects one stable occurrence of each pitch and then spreads sparse anchors across octaves. It does not identify an instrument, separate chords, automatically identify trills, or retain every repeated occurrence. Choose the wanted passage before importing; speech can also have a stable pitch. Basic attack and harmonic estimates carry modest confidence; unsupported measurements are explicitly listed.

Detected note slices lists the imported/captured anchor keys and their layers. Source slice auditions use a dedicated unpitched voice, bypassing instrument shaping (master volume and output limiting still apply). Model note auditions use reconstructed synthesis. Previews stop after three seconds; Stop preview stops immediately. Reflection-only presets disable source preview. The AU host must be rendering audio.

Add to articulation layer copies the chosen anchor and its slice into another layer while retaining its original mapping and analyzed values. Existing destination keys are protected against overwrite. This assignment does not generate a new articulation; use real source performances for trill/accent/etc. To remove or retag original detections, use the web review workflow for now.

The extension advertises its custom editor and supports compact, expanded and host-default sizes. Koala's current Mixer supports AUv3 instruments, but a real Koala loading/session pass remains necessary; these changes do not establish that the reported loading failure is resolved.

## Sound and compatibility limits

The native engine shares the web model **format**, not its complete DSP implementation. Original/sample modes retain imported waveform slices; reconstructed mode uses a compact harmonic approximation. Native sample playback currently couples pitch and duration. The web granular stretch algorithm has not been ported. Native monophonic extraction uses periodicity-based pitch detection and basic harmonic measurements; it is a separate initial analyzer, not full web-analysis parity. Reflection-only presets contain no source audio and therefore use modeled synthesis. Missing articulation anchors fall back to sustain; they do not create measured new articulations.

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
4. Switch Piano/Mallet/Fretboard/Drum Pads, rotate the device, and reach every page using the side arrows and Module menu. Compact screens can scroll the playing controls horizontally.
5. Try Mono and Legato, an imported articulation layer, sustain pedal and Panic. Save a named playable comparison, reload it and verify Tone/Behavior XY, Era and performance controls.
6. Load the AUv3 inside your host; check host MIDI, automation, resizing and save/reopen of the host session. Confirm background audio in standalone use.

Report the model file, engine mode, iPad/iOS version and host used if a sound or mapping differs. Native reconstruction and time stretching are intentionally not yet at web-engine parity.

Native model tests in CI additionally cover silence rejection, known pitches, sparse/chromatic capture, non-destructive articulation copying, destination collisions and JSON round trips. Portable DSP tests cover source preview isolation from held mono/legato voices and global pitch, stop and panic.
