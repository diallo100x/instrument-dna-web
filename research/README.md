# Instrument recognition research boundary

This directory is for comparing analyzers against human-reviewed source excerpts. No third-party analysis library, pretrained weights, training audio, or output from a third-party model is part of the shipped app. `src/recognition.js` is an independently written interchange/scorecard with no inference model. A suggestion requires agreement from two distinct systems and is not a calibrated probability or a verified instrument identity.

## Workflow

1. Create a manifest with source provenance, rights status, redistribution permission, selected time spans, and a human annotation status. `manifests/pifano-template.json` records the user's 0–6.8 second target without committing the audio or inventing ground-truth notes.
2. Have a person listen and add `truth.family`, `truth.speech`, and absolute-time `truth.notes` only when verified. Unknown labels remain absent. Store research audio privately and check its rights before sharing or training.
3. Produce one evidence JSON per tool and excerpt. Run the built-in baseline locally with `node research/native-predict.mjs research/manifests/pifano-template.json pifano-intro /path/to/file.mp3 > /private/path/native.json`. This optional runner requires an installed `ffmpeg`; it emits note times and pitches, never audio.
4. Compare `node research/compare.mjs MANIFEST.json native.json basic-pitch.json clap.json ...`. The scorecard evaluates only fields with human truth. It counts agreement on broad instrument family separately from note timing; models can disagree or abstain. Do not use a consensus suggestion as ground truth.

## Evidence interchange

```json
{
  "format":"instrument-dna-research-evidence","version":1,
  "system":{"id":"basic-pitch","version":"record-exact-version","license":"record-exact-license","role":"note-transcription"},
  "source":{"id":"user-pifano-reference","rightsStatus":"unverified","redistributionPermitted":false},
  "segments":[{"id":"pifano-intro","notes":[{"midi":69,"start":6.03,"end":6.72}]}]
}
```

`family:{"label":"flute","score":0.7}` and `speech:{"present":false,"score":0.7}` are optional. These scores are tool-specific and must not be averaged as probabilities. A system may omit tasks it cannot measure. Attach exact model/checkpoint and dataset versions, source rights, license, execution location and analysis date when curating real runs. The example values above illustrate structure, not a verified result.

## Candidate tools and boundaries

| Tool/data | Research task | Release boundary |
| --- | --- | --- |
| [Basic Pitch TS](https://github.com/spotify/basic-pitch-ts) | Note/onset transcription against native detector | Record version and Apache-2.0 notices if integrated later; evaluate iPad performance separately. |
| [OpenMIC](https://zenodo.org/records/1432913) | Broad instrument-presence benchmark | Preserve CC BY attribution and each recording's source license metadata. No training clips in factory presets by default. |
| [NSynth](https://magenta.withgoogle.com/datasets/nsynth) | Compare pitch, velocity and family behavior of isolated notes | Preserve CC BY attribution. Its `flute` family does not prove a specific recording is a Pífano. |
| [LAION-CLAP](https://github.com/LAION-AI/CLAP) | Research-only broad audio/text family and speech hypotheses | Record checkpoint, weight and training-data terms; benchmark memory, speed and errors before considering deployment. |
| [Essentia.js](https://essentia.upf.edu/licensing_information.html) | Optional isolated feature extraction for research comparison | Essentia is AGPLv3 with separate model terms/commercial licensing. Keeping it out of a release does not by itself settle rights in a derivative dataset or workflow. Review exact intended use and terms before running it for product training or curation. |

No tool output enters a factory model automatically. Selection, source isolation, labeling, and rights approval remain explicit review steps. We can replace any one analyzer without changing the manifest or the shipped synthesis engine.
