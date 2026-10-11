# Physical fitting · web 0.7.0 / native 0.3.0

Baseline before this update: `120f406ee580cffa1ffca0f65b6f0e1cdb826668`.
Existing Hybrid Original, experimental time/pitch, mallet, articulation layers,
MIDI, touch surfaces, authored physical factories and editor sizing remain available.

## Try it

Web: import audio, crop an isolated passage, choose Struck or Plucked, analyze,
review/correct mapped notes, then choose the physical fit type and click
**Fit physical model from mapped notes**. Native: import audio on Reference,
review Detected note slices, open Physical model and fit. Native fitting runs on
a background queue and refuses to overwrite sources/edits changed while fitting.

Choose **Modal** for vibraphone, glockenspiel, xylophone and other ringing bodies.
Choose **String waveguide** for a clean plucked harmonic string. Use at least
0.35 seconds of isolated decaying audio with a known root. Longer natural tails
improve reliability. Neither option is a Pifano/flute airflow model.

Switch Engine between Physical and Hybrid Original. Original anchors, measurements,
provenance and slices remain intact. Save Reflection for an audio-free model or
Playable comparison to retain private source slices as well. Do not assume source
redistribution rights. Reflections need no original audio for physical playback.
Importing new audio or changing the web anchor map invalidates previous fits;
fit the updated map again. A failed fit leaves the previous usable model intact.

## Measurements and model

Independently authored implementations in JavaScript and portable C use a Hann FFT,
log-magnitude peak interpolation and narrowband amplitude observations over time.
Log-amplitude linear regression estimates individual T60 values. Gates require
at least five observations, R² >= 0.8 and about 5.6 dB of observed decay. T60 is
usually extrapolated, not a claim that a 60 dB decay was captured. Only the strongest
32 spectral candidates are evaluated and at most 16 reliable modes retained.

String fitting requires a fundamental and at least another harmonic partial. It
searches one-pole feedback-filter loss against the measured harmonic decay slopes
and estimates the remaining broadband feedback loss. Source sample rate is stored;
playback adjusts the pole time constant and compensates its low-frequency delay.
This is a simple string-loop approximation, not complete system identification.

`extensions.physicalFits` stores version, analyzer version, kind and individual
anchor fits: root, source ID/articulation, model, frequencies, decay/regression
measurements, confidence, rejected-note reasons and unsupported measurements.
`extensions.physicalModel` remains the backward-compatible default. Optional
`waveguideTone` and `lossSampleRate` preserve fitted loop loss. Playback chooses
the nearest measured physical anchor, with deterministic lower-note tie breaking;
it does not average unrelated modal peaks or shift an entire sample. Physical
curve interpolation across registers is deferred until modes can be matched.

Confidence combines observed decay extent and regression consistency, plus string
loss residual where applicable. It is a heuristic, not a calibrated probability.
Confidence below 0.55 recommends another clean reference. Successful fits do not
modify the original analyzed harmonic parameters. Physical macro edits remain
separate and reset to the fitted model baseline.

## Limits

No automatic instrument recognition, isolated polyphonic extraction, inverse-filtered
exciter residual, independently separated body response, fitted dispersion,
nonlinear response or learned velocity layers. Exciter hardness/position are
initial model defaults, explicitly not recovered physical measurements. Resonances
follow note pitch; fixed body-resonance separation is future work. Single recordings
cannot uniquely identify every physical property. Mixed notes, speech, sustained
wind and reverberant recordings may fail or produce misleading peaks; listen to
both engines before adopting a fit. Normal acoustic decay does not prove isolation.

Original attacks are retained for Hybrid comparison; automatic mixing of those
attacks into physical resonators is not yet implemented. Next milestone: fitted
attack/excitation residual and matched modal curves between anchors, tested on
real vibraphone and plucked-string references without changing Pifano defaults.
