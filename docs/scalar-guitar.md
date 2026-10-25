# Scalar Guitar — web 0.8.0 / native 0.4.0 (build 7)

Scalar Guitar is a new authored electric-guitar starting voice based on the
user's pasted F-sharp additive example. Load **Factory instrument → DBAL · Scalar
Guitar**. Select **Physical** playback; the native factory loader selects it for
you. Main/Output on native, or Reference tuning on web, switch A4=440/432 Hz.

## What the model does

- Generates all 49 chromatic pitches E2–E6 (MIDI 40–88), covering a standard
  six-string, 24-fret guitar. Other tunings/string counts and notes outside this
  range are not included. Native touch octave controls reach the whole range.
- Uses exact equal-tempered pitch `referenceHz * 2^((midi-69)/12)`; F#4 is
  369.994423 Hz at A440 and 363.267251 Hz at A432. No rounded note-frequency table.
- Preserves the supplied eight-harmonic amplitude baseline
  `[1, .5, .6, .3, .4, .1, .25, .15]`. The pasted code omitted the harmonic-index
  array and used different realtime/export envelopes. This implementation defines
  harmonic indices 1–8 and one consistent DSP path per platform.
- Adds independently decaying harmonics, a short pick exciter, slight low-register
  inharmonicity, continuous register decay/spectral changes, pickup-position
  shaping, fixed 180/3200 Hz body/pickup filter coloration, and saturation after
  summing the partials. Those filter frequencies do not transpose with the string.
- Velocity changes upper-harmonic energy, excitation and the existing instrument
  drive response as well as level. Main Brightness/Harmonics/Noise/Drive macros,
  physical controls and XY mappings remain available.
- Provides generated sustain/picked, trill, palm mute, hard-pick accent,
  soft/finger and harmonic-emphasis behaviors through the existing articulation
  selector. Palm mute shortens decay; finger softens excitation; harmonic emphasis
  reduces the fundamental. These are authored behaviors, not recorded layers or
  automatic articulation recognition. Existing high-velocity trill switching is
  optional, rather than silently mixing random trills into normal sustains.
- Retains sparse authored anchor descriptors every four semitones, global DNA and
  three register summaries. For example F#4 is bracketed by E4/G#4 descriptors.
  Existing Reconstructed mode interpolates their harmonic DNA; the Scalar engine
  evaluates its continuous register law directly at each played note. It does not
  interpolate or pitch-shift a hidden recording.
- Saves reference tuning and edits in audio-free Reflections. Native AU address
  33 is appended for reference tuning; prior 0–32 parameter addresses remain
  unchanged. Old presets/sessions without tuning default to 440 Hz.

## What is not claimed

No electric-guitar recording was analyzed for this preset. All `analyzed` fields
remain null and confidence zero. The output is an authored approximation that needs
listening and performance comparison before claiming a realistic captured guitar.
It is not a learned pickup, amplifier/cabinet, feedback, fret/string-interaction or
coupled-body model. Saturation is not oversampled. Mono/Legato and bend controls
remain available, but web legato is a crossfade/glide between voices, not a measured
hammer-on or pull-off. Native independent sample time stretching is still absent.

“Scalar Guitar” is the instrument name. The pasted source's scalar-energy,
vacuum-energy and therapeutic claims are not DSP features or product claims.
The pasted lecture transcript and external prose/code are not bundled.

New `additive-string` models require this or a newer engine. Earlier presets still
load; earlier engines cannot reproduce the new Scalar voice from the Reflection.
No source audio is embedded or redistributed.

## Validation and device pass

Automated tests cover 432/440 pitch including F#4, harmonic evolution, velocity
spectra, palm-mute decay, every guitar key and generated behavior, malformed tuning,
JSON round trips and identical web/native factory data. Existing DSP, sample,
preview, source-analysis, physical-fitting and state tests remain in the suites.
Browser acceptance additionally exercises live AudioWorklet parameters, layer
sound, tuning/layer save/load, synthetic MIDI and legacy import/preview playback.
Native CI compiles both targets for simulator and Release iOS device with the
15.4 minimum, and hosts the actual AUv3 editor/audio extension. These checks do not
replace testing the signed build on a real iPad, or demonstrate Koala compatibility.

For listening: load Scalar Guitar, compare F#4 at 440/432, play E2–E6, compare
soft/hard velocities, Palm mute/Sustain, increase Drive and try Mono/Legato. Save a
named Reflection at 432, reload it and reopen an AU host session. Compare the same
phrase against your preferred source guitar before adjusting its authored model.
