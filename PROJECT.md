# Instrument DNA Web 0.3

Static browser prototype. Serve with `python3 -m http.server 8000`; open localhost:8000. Run model tests with `npm test`. No build or third-party runtime dependency. Main branch is deployed by the repository's existing GitHub Pages configuration, if enabled remotely.

## Current behavior

- Decode local audio, show waveform, segment isolated notes using energy gating and autocorrelation, retain the best event per pitch and select up to 1/3/6/12 anchors per octave. Three is the default target; missing recordings cannot be invented.
- Preserve event measurements and individual anchor parameters, plus global and octave summaries. Estimate missing note parameters by interpolation between neighboring anchors and expose gap-based confidence and a suggested reference note.
- Play imported audio slices in Hybrid/Raw modes. Raw requires an exact anchor. Hybrid uses the closest slice with playback-rate pitch shift; this remains sample audition, not physically modeled interpolation. Reconstructed uses an oscillator and modeled brightness envelope. Imported DNA Reflections contain no audio and play via the oscillator.
- Save/load versioned JSON DNA Reflections containing source rights metadata, model hierarchy, confidence and unsupported-measurement markers. Source audio is never embedded. Edit global numeric offsets in Advanced, reset or compare original vs edited state. Main macros adjust attack, brightness and dynamics; XY Tone X affects brightness. The remaining macros and axes are stored for future mapping and currently do not change sound.
- Recording Era low-pass presets are separate from instrument data and adjustable in amount. They are illustrative effects, not historically measured models. MIDI input and keyboard audition are supported where the browser permits MIDI.

## Boundaries and next steps

Pitch segmentation expects isolated monophonic notes and can misidentify noisy/polyphonic or continuous phrases. Brightness is a zero-crossing proxy; harmonic, formant, resonance, noise-spectrum and nonlinear measurements are explicitly unsupported. No trained historical presets or claims about archive rights. Sample slots and independent follow flags are schema only; no sample-driven resonator yet. Reconstructed sound is basic oscillator synthesis; source slices are not retained in exported JSON. Next milestone: reliable windowed spectral/harmonic analysis with confidence, followed by a real excitation/resonator engine and purposeful macro mapping.

## Audio import formats

The file picker explicitly offers WAV, MP3, AAC/M4A/MP4, FLAC, Ogg Vorbis, Ogg Opus, uncompressed AIFF/AIFC, CAF and WebM. Browser-native decoding is attempted first. Lightweight, locally hosted decoders cover MP3, FLAC, Ogg Vorbis and Ogg Opus when native decoding fails; a PCM AIFF parser covers 8/16/24/32-bit AIFF and `sowt` AIFC. AAC/M4A, CAF and WebM require the browser to support the file's actual codec. Protected/DRM media, WMA and other proprietary or unusual codecs are not supported. Decode failures now report the format and keep a separate browser media preview available for troubleshooting. A preview that plays while instrument audition is silent points to the Web Audio path; silence in both suggests browser or system output configuration.
