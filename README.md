
### Physical fitting · v0.7.0 web / v0.3.0 AUv3

Clean struck/plucked source notes can now fit per-anchor modal frequencies/decay
or simple string-loop damping. Analyze and review notes, then **Fit physical model**.
Keep Hybrid Original for comparison; save an audio-free Reflection or a playable
comparison with slices. [Workflow and limitations](docs/physical-fitting.md).

Scalar Guitar is available in web **0.8.0** and native **0.4.0 build 7**: an authored
F#-recipe electric-guitar voice across E2–E6, generated articulation behaviors and
saved A4=432/440 tuning. See [Scalar Guitar](docs/scalar-guitar.md) for usage and
limits; no recordings or claims of measured guitar DNA are bundled.

The Scalar Guitar performance update is **web 0.8.1 / native 0.4.1 build 8**.
It adds authored neck/bridge/piezo profiles, harmonic phases, delayed vibrato,
continuous web legato, slide audition, body texture, room and web WAV audition
export. A separate Original factory preset preserves the first Scalar Guitar.
See [controls, limits and completed acceptance](docs/scalar-guitar.md).

Web **0.8.2** adds Compatibility audio and Recover instrument audio for sessions
where the direct test tone works but the live model is silent. It plays rendered
notes from the same model through an independent output path. See
[recovery behavior and limits](docs/web-audio-recovery.md). Native remains 0.4.1.
