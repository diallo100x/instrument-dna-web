# Physical fitting implementation report

1. **Before:** web 0.6.0 / AUv3 0.2.1 offered analyzed harmonic/hybrid playback,
   source cropping and note extraction, sparse anchors, MIDI/touch performance,
   articulation layers, named presets and six authored physical starter instruments.
   Automatic physical parameter fitting was absent.
2. **Added:** web 0.7.0 / AUv3 0.3.0 fit decaying reference PCM into measured modal
   frequencies, gains and independent decay estimates, or simple plucked-string
   loop damping and broadband feedback loss. Both expose fitting and confidence.
3. **Changed:** physical playback selects individual fitted anchors. Original
   harmonic measurements and recorded slices stay intact. Comparison saves retain
   the selected engine. Native fitting runs in the background, protects changed
   source documents and retains musical macro edits made while fitting.
4. **Functional:** import/review mapped notes → fit → Physical playback; switch to
   Hybrid Original; save/load audio-free Reflections or audio-bearing comparisons;
   physical reset; heuristic confidence and reference recommendations.
5. **Foundations:** nearest-anchor physical mapping is implemented; matching modes
   and interpolating their curves across registers remain future work. Exciter
   parameters start from explicit model defaults. Wind excitation, separated body
   response, dispersion, excitation residuals and learned dynamics are unsupported.
6. **Testing:** 44 Node tests; native C tests with address/undefined-behavior
   sanitizers; deterministic frequency/decay/loss recovery and rejection cases;
   browser WAV import, modal/string fitting, audible AudioWorklet output, Hybrid
   comparison, preset roundtrips, source preview and synthetic MIDI with zero
   console/page errors; Apple audio-unit rendering/state/validation; Xcode builds
   for standalone and embedded AUv3; iPad simulator editor and fitting/save checks.
   The simulator fitting test also checks retaining a macro edit made during fitting.
   Physical MIDI hardware, real Koala hosting, and new MP3 import were not retested.
7. **Known limits:** fitting is an approximation for isolated decaying notes, not
   instrument recognition or complete physical recovery. Real acoustic likeness
   needs listening comparisons. Original attacks are available in Hybrid; they are
   not yet inverse-filtered and injected into physical models. Koala's previously
   patched editor still requires a real-device retest. Distribution is an Xcode
   source project, not a signed IPA/TestFlight installation.
8. **Commits:**

   | Commit | Change |
   |---|---|
   | `abd897b` | Modal/string fitting DSP and recovery tests |
   | `9c7cc1b` | Web/AUv3 per-anchor fitting and Hybrid preservation |
   | `47cebe7` | Browser/Apple acceptance and fitting documentation |
   | `a5698e8` | C linkage for the Apple bridge |
   | `770aca9` | Confidence display and independent browser source fixture |
   | `6f8937f` | Comparison-mode recall and simulator fitting action checks |
   | `909ee5a` | Web version label and DSP cache refresh |
   | `8c3e2b4` | Float32/JSON loss-coefficient boundaries |
   | `e1e37d3` | Preserve live musical macro edits during native fitting |

9. **Repository/branch:** `diallo100x/instrument-dna-web`, `main`. Baseline
   `120f406ee580cffa1ffca0f65b6f0e1cdb826668` is preserved in history and documented
   in the implementation guide. Existing AU identifiers and parameter addresses
   remain stable.
10. **Next milestone:** estimate an attack/excitation residual, combine it with
    fitted resonators, and match modal curves between anchors. Compare against
    real vibraphone and plucked-string references while keeping Pifano Hybrid.

See [workflow and fitting limits](physical-fitting.md).

Completed validation:

- [Web browser acceptance](https://github.com/diallo100x/instrument-dna-web/actions/runs/38116019195): passed on `8c3e2b4` (latest web code).
- [Apple/native build and simulator fitting acceptance](https://github.com/diallo100x/instrument-dna-web/actions/runs/38116179107): passed on `e1e37d3` (latest native code).
- Public page checked directly: v0.7.0 and the fitting controls are deployed.
- Early integration runs exposed missing C/C++ linkage and a browser fixture that
  retained a prior sustained reference. Both were corrected and acceptance rerun.
