# Coupled-body update validation — 2026-10-31

Preserved baseline: `694b69dfcabba08d09c1cfc4c5317e3eaf88758c`.
Tested native code: `2a3715eabb12c8ad9832c64e0544885366665f35`.
Tested web source: `c273708a03a8b7bd1e75e4f9683d72334a2ad8a3` (native-only
synchronization changes after this did not change browser code).
Release: web 0.8.3; native iPad/Mac 0.4.3 build 10; AU version 65546.

## Passed

- 59 Node tests, including all 15 factory Reflection roundtrips, source audio
  analysis, legacy formats, old synthesis and new coupled-body behavior.
- Eight original factory JSON hashes unchanged, plus exact before/after comparison
  of their reference renders in the same runtime.
- ASan/UBSan portable kernel, concurrent model publication, modal/string fitting,
  coupled strike/pluck/air bounds at 8–192 kHz, body tracking and invalid models.
- Apple audio unit integration: all 15 factory instruments audible, 45 parameters,
  older 41-parameter host-state compatibility, new control recall, malformed body
  rejection, 48 kHz mono/stereo/interleaved and large host buffers.
- Chromium and WebKit: all 15 live presets audible; new controls and audio-free
  Reflection save/load; audible coupled compatibility rendering; existing source
  import/analysis/preview, synthetic Web MIDI, fitting and Hybrid playback;
  no console/page errors on the final expanded run.
- Universal Mac build (arm64/x86_64), editor resizing, all factory audio,
  discovered out-of-process AUv3, MIDI render and DAW-style track-mixer routing.
- iPad simulator build and signed simulator launch; editor and fitting checks;
  standalone audio recovery; shipped out-of-process AUv3 remote editor and audible
  render. Unsigned Release device bundles confirm deployment minimum 15.4.

## CI evidence

- Web Chromium + WebKit: https://github.com/diallo100x/instrument-dna-web/actions/runs/41206179062
- Native Mac: https://github.com/diallo100x/instrument-dna-web/actions/runs/41206451251
- Native iOS: https://github.com/diallo100x/instrument-dna-web/actions/runs/41206451211

An earlier iOS fitting check exposed stale queued parameter notifications in the
UI cache. Commit 2a3715e corrects that synchronization; the complete iOS run then
passed. An earlier Chromium run reported a guitar legato assertion; the final
expanded Chromium/WebKit suite passed that assertion without altering the legacy
guitar DSP or weakening the assertion. That isolated failure has not been
reproduced or attributed to a specific product defect.

## Not established by these checks

Physical iPadOS 15.4.1/Koala/DBAL sessions on the owner's devices; real MIDI
hardware and real-time worst-case CPU capacity; acoustic measurement accuracy
or perceptual parity with real instruments. New presets are approximate authored
models. No third-party preset conversion, learned two-body fitting, nonlinear
reed/bow model or external sample-driven exciter is claimed.
