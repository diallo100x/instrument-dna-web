# DNAi: intelligent mapping, agent refinement, and AUv3 parity contract

## Reality check (2026-11-04)
- Mac DNAi has deterministic onset slices, autocorrelation-based monophonic pitch guesses, manual key correction, JSON export, and a new explainable phrase summary. These are not neural transcription, articulation recognition, or playable DNAi patches.
- Shipped Mac AUv3 registers as aumu/InDN/DbAL and hosts the existing Instrument DNA editor. The DNAi mapping workspace is not yet inside the AUv3 editor.
- Web implementation includes analysis, articulation layers, source mapping, physical fitting, spectral/physical engines, and model comparison. Features must be tested individually before parity is claimed.

## Immediate acceptance gates
1. Export schema dbal.dnai.mapping.v1; verify first sounding, lowest, and phrase anchor are distinct from tentative tonic. Preserve original audio, timing and overlapping resonance.
2. Define a versioned playable model package with source sample references, root/anchor, note regions, articulation labels, velocity layers, physical-fit parameters, and schema migrations. Do not conflate mapping metadata with an AU preset.
3. Add AUv3 editor navigation to the same analyzer/model workspace where technically supported. Heavy analysis is background/offline only; render callbacks remain allocation-free and deterministic.
4. Add Basic Pitch or equivalent only after model packaging, license, memory footprint, iPadOS 15.4.1 deployment, and offline transcription quality are verified. Retain baseline DSP for fallback.
5. Map instrument recognition, source selection, crop/zoom, pitch/cents, manual mapping, articulations, legato, hybrid stretch, model naming, velocity switching, physical fitting, and persistent save/reload against the web feature inventory. Every item needs an executable test on Mac AUv3 and iPad AUv3.
6. In DBAL, verify AU component discovery, MIDI note-on/off, editor opening, fullState save/reload, no-solo audio, and offline export. Missing plugins retain saved state and are reported explicitly.

## OMG-Agent adaptation (not a ready-made audio model)
Source: https://github.com/F0LDRA1N/OMG-Agent-WWW2027
The repository implements a multimodal sentiment-analysis planner/retriever/executor with missing-modality reconstruction. It is NOT trained for musical pitch, technique, instrument synthesis or audio resynthesis. Reuse architectural ideas, not its pretrained task claims:
- Planner: inspect audio, optional notation and video, instrument family context, and requested articulation.
- Retriever: select licensed reference examples and verified prior instrument fits; never use test-set references during training.
- Executor: propose candidate note maps, articulations and DSP parameters; render audio with DNA's actual engine.
- Verifier: compare reference/render pitch contours, onset accuracy, spectral envelopes, decay and human listening judgments.
- Refiner: bounded parameter search with rollback, immutable source audio, checkpointed versioned candidate models, explicit user approval before replacing a model.
- Training/fine-tuning: separate, opt-in offline job; report actual dataset, checkpoint, license, hardware, evaluation and provenance. No implicit user-data upload or shared learning.

## Release principle
Web parity means tested behavior, not visually matching controls. Ship progressively with test evidence; preserve basic DNA and stable AU component IDs so existing DAW sessions survive.
