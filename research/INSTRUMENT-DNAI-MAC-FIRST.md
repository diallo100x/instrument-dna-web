# Instrument DNAi — Mac-first implementation contract

Instrument DNAi is a separate product based on Instrument DNA. Preserve original Instrument DNA build targets and model compatibility. Work on this branch until Mac tests pass.

## Delivery sequence

1. macOS standalone: import local WAV/AIFF/MP3, non-destructive waveform selection, adjustable start/end markers and preview.
2. Intelligent slicing at launch: onset candidates, stable-pitch windows, release-tail handling, confidence scores, manual split/merge/trim and pitch override. Never assume every transient is a new note.
3. Auto mapping at launch: frequency-to-MIDI note assignment, root-note correction, keyboard visualization, detection confidence and 3–4 source-note to 12-note octave synthesis mapping. Preserve source-to-generated provenance.
4. Playback: use existing Instrument DNA synthesis engine; offline analysis must not run in real-time render callback. Persist source slices, generated parameters and manual edits.
5. macOS AUv3: validate discovery, editor, factory preset and DAW routing after standalone playback passes.
6. iPad AUv3 + containing app: same preset format and playback, offline analysis with bounded memory; minimum iOS 15.4.1 if supported by actual SDK/dependencies.
7. Later: articulation/velocity layers, touch slides, acoustic retrieval, opt-in shared intelligence, on-demand instrument stems. YouTube link support must respect platform rules and rights; link alone is not a license to download.

## Analysis contract

Input: PCM frames, sample rate, channel count, selected frame interval.
Output: ordered Slice { startFrame, endFrame, estimatedMIDINote?, centsOffset?, pitchConfidence, onsetConfidence, articulationLabel?, sourceOrGenerated }.
Analysis is cancellable, deterministic for a given version and input, and runs off the audio thread.
Pitch mapping uses concert A=440 Hz by default with user calibration option.
Never fabricate articulation labels as observed facts: generated layers and low-confidence guesses must be marked.

## Mac acceptance tests

- Single isolated notes map to the expected MIDI note within +/- 50 cents.
- A legato two-note phrase does not create arbitrary slices for each vibrato cycle.
- Repeated notes at the same pitch can produce distinct onset slices.
- Changing selection markers never modifies the original source file.
- Three or four reference notes produce a 12-key map with provenance and playable output.
- Preset save/reopen preserves corrected note positions and slice bounds.
- Analysis can be cancelled and does not cause audio-thread dropouts.
- Standalone emits sound before AUv3 host testing starts.

## iPad parity gate

No iPad release until the Mac standalone workflow is verified. Reuse the same versioned patch schema and export a lightweight, self-contained playback model. Keep generated model and user edits compatible between Mac and iPad.

## Build guidance

Use the existing native/InstrumentDNAMac project as the Mac baseline; do not overwrite original Instrument DNA targets. Keep Xcode DerivedData and logs on /Volumes/Untitled/DBAL-Builds when available.

This document is an implementation plan, not evidence of a compiled or tested DNAi binary.
