# DNAi Phrase-First Steelpan Performance Modeling

## Purpose
Make an arpeggiated steelpan passage a first-class DNAi instrument reference. Do not require isolated notes before creating a playable phrase instrument. Preserve the full recorded phrase and optionally deconstruct it into note events later.

## Harmoniq study
Source: https://github.com/kandisaikishore/Harmoniq
- `src/utils/musicTheory.ts`: pitch classes, intervals, scales, chords, frequency/MIDI transformations, and note spelling; useful as musical references, not a pitch estimator.
- `src/utils/audioSynth.ts`: `playArpeggio` and `playStrum` illustrate note scheduling and temporal relationships, but synthesize generic tones; not steelpan timbre capture or transcription.
- Project README identifies React/TypeScript and Gemini for theory assistance. No demonstrated recording-to-MIDI transcription model or steelpan physical modeling.
- No license was identified in the README. Prefer independently implemented algorithms and concepts rather than copying source until permissions are verified.

## Design and root semantics
Store distinct fields:
- `firstSoundingMidi` — first reliable pitch onset, preserving absolute pitch.
- `lowestSoundingMidi` — minimum stable observed pitch; not automatically root.
- `tonicPitchClass` — inferred harmonic center, with ranked alternative hypotheses and confidence.
- `phraseAnchorMidi` — the MIDI key that triggers original playback at unity transpose; default to first reliable pitch and allow explicit user change.
- `referenceTuningHz` and optional per-event cents deviation.

A phrase can be chord inversion or start away from tonic. If harmonic evidence insufficient, mark tonic unknown, never silently label the first note as harmonic root.

## Phrase model format: `DNAiPhrasePreset`
- source recording bookmark or embedded original file reference, frame range and sample rate.
- raw phrase audio, attack/release and dynamics preserved, immutable source.
- anchor, first/lowest sounding pitch, tonic candidates, scale/chord interpretations and confidences.
- performance timing map and transient grid; optional inferred note events.
- transpose settings: preserve duration and preserve pitch/time independence when possible. Resynthesis quality at wide transpositions is a separate validation target.
- optional deconstructed note bank, articulation descriptors and struck-plate resonant partial profile.
- save/load must survive app restart and restore editing decisions.

## Analysis algorithm: Mac first, shared iPad later
1. Load user-provided authorized local recording, non-destructively choose region; process offline with bounded memory and progress/cancel.
2. Detect strike onsets and decays with spectral flux and amplitude envelope; repeated strikes may occur before previous ringing decays.
3. Perform per-frame multipitch or harmonic salience analysis; steelpan partials can be inharmonic and may include tuned overtone relationships. Avoid over-weighting the strongest spectral partial.
4. Track stable note candidates with pitch class and octave, cents and confidence, retaining multiple simultaneous candidates when notes overlap.
5. Infer chord, tonal center, scale and alternatives using pitch histogram, interval relationships, rhythmic accent, cadence/resolution; never treat note order or lowest note as proof of tonic.
6. Map original phrase to `phraseAnchorMidi`; trigger at same MIDI key with unchanged recorded pitch. Shift transposition by semitone offset `triggerMidi - phraseAnchorMidi`. Anchor editable without changing original source.
7. Default playback: one-key full phrase, original tempo and feel. Optional tempo sync/time stretching independently of semitone transpose.
8. Optional `Deconstruct`: annotate onset/offsets, MIDI events with uncertainty, isolate strikes despite overlapping ringing, manually adjust and assign velocity/alternates. Keep original phrase as independent articulation layer.
9. Later add physical/resonant plate modeling or hybrid sample/model to extend sparse note coverage; compare against preserved original at unity pitch.

## Mac UI behavior
DNAi Mapping workspace > mode segmented control: Isolated Notes | Performance Phrase.
In Performance Phrase: open file, crop, analyze, show waveform and strike markers; visible chips 'First note', 'Lowest note', 'Likely tonal center', 'Phrase trigger key', confidence. Play Original, Play Mapped Phrase, Set Anchor, Deconstruct Notes, Save DNAi Phrase.
MIDI keyboard highlights actual trigger anchor and transpositions; visual phrase timeline later shows events/overlap.
Do not confuse 'harmonic root' with the key used to trigger phrase playback.

## Test acceptance
- Synthetic three-note arpeggio starting on the third: original phrase anchor is observed first note, inferred root can differ; neither may be lowest.
- Recording at unknown key: original anchor playback is not accidentally transposed.
- Repeated steelpan strikes are detected despite lingering metallic ringing.
- Overlapping notes remain intact in original phrase playback; optional MIDI analysis expresses uncertainty.
- Relative rhythm, dynamics, attack and tail retained in phrase mode.
- Save/reopen, manual anchor overrides and range crop stable.
- Mac regression compile; real steelpan tests; iPad share analyzer models with iOS 15.4.1 floor.
