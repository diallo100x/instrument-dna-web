Current optional coupled-body additions and compatibility notes: [Coupled bodies](coupled-bodies.md). The original physical-engine notes below describe its initial release.

# Physical Instrument DNA v1

Baseline before this update: f502bffbaf3bb73688f8745c2313f44e5146ad15. Existing hybrid/sample, reconstructed and mallet engines remain available.

The first physical engine and six presets are original Diallo Beats Audio Lab implementations/designs. No RipplerX/Resonarium GPL source or factory presets, Faust source/generated code, or reference recordings are bundled. The research references are https://github.com/tiagolr/ripplerx, https://github.com/gabrielsoule/resonarium and https://faustlibraries.grame.fr/libs/physmodels/. We adopt standard DSP principles: driven damped resonant modes, separate filtered excitation, fractional-delay string feedback, velocity-dependent excitation and damping. Direct Faust integration and third-party preset conversion remain future work; these are not Faust/RipplerX/Resonarium preset replicas.

`extensions.physicalModel` is an optional versioned model containing kind (`modal` or `waveguide`), modal frequency ratios/gains/T60 seconds, exciter hardness/position/noise, decay and continuous-excitation flag. JSON contains no audio. Unsupported versions/configurations are rejected. Existing presets without this extension use their existing playback modes. Native AU parameter addresses 0–28 stay stable; mode 4 selects Physical, and new controls are appended.

Factory sounds: Warm Marimba, Wooden Kalimba, Glass Chime, Hand Drum, Plucked String and experimental Reed Pipe. They are deliberately approximate designed instruments, not instrument-recognition results or measured acoustic replicas. Authored anchors have null analyzed values and zero measurement confidence. The reed uses continuously excited odd modal resonances; a nonlinear reed/mouthpiece wind model is not implemented.

Modal filters are driven by a shaped transient/noise exciter. Individual resonances decay independently; high modes are limited below Nyquist. The plucked string uses a bounded feedback delay and frequency-dependent loss. Voice storage and coefficients are bounded. Native renders allocate no memory; pitch/control coefficient updates run at a reduced rate. Era processing remains separate.

The browser uses an AudioWorklet for live physical voices; it requires HTTPS/localhost and AudioWorklet support. Native C uses the same model format and equations. No perfect cross-platform numerical identity is promised. Presets and physical edits save as normal Reflections; their original design remains in physicalModel and edited controls are retained separately in physicalControls.

Physical factory presets contain no measured articulation layers. Web Physical currently uses excitation/envelope controls and pitch glide rather than recorded-layer/generated-trill routing; native generated trills use its shared pitch path.

Limitations: no automatic fitting of modal ratios/T60 to input audio, coupled bodies, independent formant/resonator/filter pitch tracking, live sample-driven resonators, true bowed/friction or nonlinear reed model, continuous MPE pressure/timbre, or vendor-specific preset import yet. A fixed authored model can be combined with future fitted measurements without changing the Reflection schema. Adding source audio to a physical preset must disable its physical extension before reverting to analyzed reconstruction, so authored physics is never mislabeled as learned from that audio.
