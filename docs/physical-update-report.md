# Physical Instrument DNA update — web 0.6.0 / native 0.2.0

1. **Before:** web analysis, crop/zoom, sparse anchors, hybrid/reconstructed/mallet/sample playback, multi-source articulation layers, mono/legato, MIDI and named Reflection/comparison save/load. Native iPad/AUv3 already had touch surfaces, module navigation, native monophonic extraction, note previews and host state recall. Preserved baseline: `f502bffbaf3bb73688f8745c2313f44e5146ad15`.

2. **Added:** a driven modal resonator engine and fractional-delay plucked-string engine; six audio-free factory instruments: Warm Marimba, Wooden Kalimba, Glass Chime, Hand Drum, Plucked String and experimental Reed Pipe. Factory data is identical in web and native resources.

3. **Changed:** Physical joins the existing engine choices. Factory loading is available on Instrument map; hardness, strike/pluck position, damping and exciter noise have a separate module. Macros/XY shape excitation, modal energy and body response. Native AU addresses 0–28 stay stable; controls 29–32 are appended. Authored null analyzed values now display honestly in Advanced. New source analysis clears authored physics rather than labeling it as measured.

4. **Functional:** real-time browser AudioWorklet and preallocated native C synthesis; velocity-dependent timbre, independently decaying modal frequencies, pitch-tracked string feedback, live physical controls, factory selection and physical Reflection/state recall. No embedded reference audio is needed. Existing playback modes remain available.

5. **Foundations:** the versioned `extensions.physicalModel` stores original design; `physicalControls` stores separate user edits. Authored anchors retain null measurements and zero analysis confidence. This supports future audio-derived fitting. These are designed starting sounds, not automatically recognized acoustic replicas.

6. **Testing:** 40/40 Node tests; portable native DSP under ASan/UBSan and project checks passed. Chromium verified audible output from all six factory presets, physical edit export/import, source WAV import/analysis, source slice preview, Hybrid audition and synthetic Web MIDI input, with zero console/page errors. Apple AU tests passed for all six factories, malformed physical-field rejection, 33 parameters and host recall. Native extraction/articulation tests passed. Both Xcode simulator targets compiled successfully.
   - [Browser acceptance](https://github.com/diallo100x/instrument-dna-web/actions/runs/38097534907)
   - [Apple/native acceptance](https://github.com/diallo100x/instrument-dna-web/actions/runs/38097534900)
   - iPad simulator startup and audio-ready marker passed; interface screenshots were inspected.

7. **Known limits:** no audio-to-physical-model fitting, coupled resonators, true reed/friction model, sample-driven resonator routing or vendor preset conversion yet. Reed Pipe uses continuous noise through odd modal resonators. Physical factory presets have no measured articulation layers; web Physical currently uses excitation/envelope controls and pitch glide rather than recorded-layer/generated-trill routing. Native sample pitch/duration remain coupled. AudioWorklet requires HTTPS/localhost. Real iPad latency, external MIDI, Logic/Koala host acceptance and signing/distribution remain device work; the reported Koala issue is not certified fixed.

8. **Commits:** `dd0d432` model/DSP/schema/factories; `82f3862` web/AUv3 integration and acceptance; `3758495` source-analysis separation; `78b18f4` correct browser source profile; `472b0f7` MIDI/preview coverage; `6f652a9` validation and macro connections. A final documentation commit records verification.

9. **Repository/branch:** [diallo100x/instrument-dna-web](https://github.com/diallo100x/instrument-dna-web), `main`. [Web build](https://diallo100x.github.io/instrument-dna-web/?v=0.6.0). For native open `native/InstrumentDNA/InstrumentDNA.xcodeproj` and run the **InstrumentDNA** containing-app scheme. No signed installable IPA is produced by this environment.

10. **Next milestone:** estimate resonant peaks and independent decay times from clean struck/plucked reference notes, then blend retained natural attack slices with their fitted physical bodies. Compare against the current Pifano/vibes hybrid models before changing their default engines.

The DSP and factory designs are original Diallo Beats Audio Lab work. No RipplerX/Resonarium GPL code or presets, Faust code, or historical source recordings are bundled. See [physical modeling](physical-modeling.md) for the format and technical limits.
