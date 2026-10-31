# Optional coupled-body bank — web 0.8.3 / native 0.4.3 build 10

Preserved baseline: commit `694b69dfcabba08d09c1cfc4c5317e3eaf88758c`.
All eight original factory JSON files are unchanged. Their reference-note renders
were compared before/after the implementation and were byte-identical in the
same runtime. `tests/legacy-factory-hashes.json` guards the original preset files.
Hybrid Original, Hybrid Stretch, Raw, Reconstructed, Mallet, prior modal/string
physics, existing Scalar Guitar variants, sample import and user models remain
on their existing code paths. Loading a new preset is explicit; none replaces
an existing factory ID or rewrites a saved user Reflection.

## New optional sounds

| Factory ID | Original authored design |
| --- | --- |
| coupled-vibes | Metal bar and pitched resonator |
| coupled-marimba | Wooden bar and tube-like body |
| coupled-xylophone | Bright struck bar and short body |
| coupled-plate | Rectangular plate modes and supporting body |
| coupled-membrane | Rectangular membrane modes and shell |
| coupled-string | Plucked harmonic string modes and fixed body |
| coupled-air-pipe | Continuously driven open-pipe-like modal sound, experimental |

Choose them in Factory instruments, then use Physical playback. The native
Physical model module and web physical panel expose Body coupling, Resonator mix,
Resonator pitch follow and Velocity timbre response in addition to hardness,
position, damping and excitation noise. Follow 0 fixes body frequencies to its
reference; 1 tracks the played pitch; intermediate values give partial tracking.
Instrument tuning continues to use the existing 432/435/440/444 choices.

## DSP and model format

The separate `coupled-modal` branch uses a raised-sine force pulse (strike), an
impulse/noise excitation (pluck), or continuous noise/periodic excitation (air).
Hardness and velocity affect pulse duration, modal energy and decay. Each primary
mode has a ratio, gain and T60, with mild optional inharmonicity/material damping.
The primary object's output drives a second normalized modal bank. This is
**one-way serial coupling**, not bidirectional, energy-conserving physical coupling.
There is no feedback between objects; resonant state is bounded, coefficients
are updated at a reduced rate, and native render storage is preallocated.

`extensions.physicalModel.coupledBody` stores secondary modes, excitation type,
reference Hz, coupling/mix/follow/velocity baselines, contact duration, material
loss and inharmonicity. `extensions.physicalControls` stores user edits separately.
The outer physical format remains version 1, with a new explicit kind. Older
Instrument DNA builds will reject the new kind; they should continue using the
original eight presets or their old saved files. Old Reflection/host-state input
is accepted by the new build. Native AU addresses 0–40 remain unchanged; 41–44
are appended for the four coupled-body controls. No component or bundle IDs,
minimum OS targets or existing preset names have changed.

## Provenance and scope

All new DSP, parameter designs and presets were authored for Diallo Beats Audio
Lab using elementary damped-mode relationships. No RipplerX GPL implementation,
factory XML preset, excitation audio, AAS/Chromaphone-derived table, FAUST source
or generated model asset is bundled. RipplerX is a research reference for the
exciter/object/body design approach: https://github.com/tiagolr/ripplerx.
Plate and membrane ratios are independently generated from rectangular-object
frequency relationships; bar/string/body tunings are original illustrative
sound designs. These are approximate models, not validated acoustic replicas.

All factory provenance marks them authored, with null analyzed values and zero
measurement confidence. Reflections contain no audio. The existing measured
modal/string fitter remains separate; fitting two bodies from audio, nonlinear
reed/jet/bow physics, external sample-driven excitation, vendor preset conversion,
continuous MPE timbre, and historically measured material profiles are not added.
Pifano and existing vibraphone/guitar models are not automatically replaced.

## Build and verify

- `npm test`: Reflection/validation, baseline hashes, bounds, coupling and velocity
  behavior, body tracking, old analyzers and old synthesis regressions.
- `native/InstrumentDNA/test.sh`: ASan/UBSan kernel/fitter/new-coupled-body tests.
- Apple AU integration: all fifteen factory sounds, appended parameter recall,
  older 41-value host-state load and malformed coupled-preset rejection.
- Browser acceptance on Chromium and WebKit: all fifteen live presets, edited
  coupled Reflection roundtrip and audible compatibility fallback, plus existing
  import, analysis, synthetic MIDI, source preview and hybrid acceptance.
- Native Mac/iPad builds and host/editor checks run in the existing Apple CI.

The source ZIPs require Xcode and signing for device installation. Physical iPad
15.4.1, Koala and owner-device DAW sessions still need hardware acceptance;
simulator, offline audio and automated host checks do not establish those passes.

To regenerate only this optional bank without overwriting the old factory files:
`node tools/build-coupled-presets.mjs`.
