# AUv3 0.3.1 / build 5 · host compatibility

The user confirmed that 0.3.0 still shows no editor and produces no sound in Koala.
The baseline is preserved at `18b8c18d0214838a2e8ba65a71b9ba9b28f92dee`.

The earlier tests constructed the audio unit and editor in the app process. A new
host test now instantiates the installed `InDN` extension out of process, requests
its remote editor through Apple's API, displays it in a host container, sends MIDI
and measures its rendered output. The 0.3.0 baseline passed that generic host test,
and the screenshot shows its editor. The exact Koala failure is therefore still
not reproduced here; these are host interoperability fixes, not a certification
that Koala is fixed.

## Changes

- Explicit zero-input mono/stereo channel capabilities.
- Bounded host render support up to 65,536 frames; scratch buffers are preallocated,
  with no vector resizing or allocation in the render callback.
- An output-bus adapter preserves canonical channel/rate bookkeeping while exposing
  the supported Float32 client layout. Mono, planar stereo and packed stereo output
  are handled with correct byte sizes. Caller buffer bounds are checked, and
  AU-owned output buffers can be reused safely.
- Supported bus-format changes are accepted before render allocation. Changing an
  active bus remains prohibited. Output rates are bounded to the DSP's 8–192 kHz.
- Stale OutputIsSilence flags are cleared when returning rendered output.
- CFBundleShortVersionString 0.3.1, build 5; AudioComponents version rises from
  65536 to 65541 so host scans can identify the updated component. Bundle IDs,
  `aumu/DbAL/InDN`, principal class and all 33 parameter addresses remain stable.
- Startup logs identify factory invocation, editor installation and negotiated
  audio format/frame limits. No source audio is logged.

## Installation / device retest

Open `InstrumentDNA.xcodeproj`, choose the **InstrumentDNA** containing-app scheme,
use the existing signing team and run on the iPad. Install over the current app.
Open the standalone app and confirm About says 0.3.1. Fully close/reopen Koala and
add a fresh Instrument DNA instance to a new test song.

If it is still blank, the next useful evidence is the Koala version, iPadOS version,
whether the standalone app and Logic can open this exact build, and an
InstrumentDNAInstrument crash/termination entry from Settings → Privacy & Security
→ Analytics & Improvements → Analytics Data. Those distinguish host negotiation,
registration caching and extension termination. Do not discard existing presets.

The native ZIP is an Xcode source project, not a signed IPA/TestFlight app. Koala
itself is not installed or operated in this environment.

## Completed validation

- 44 web/model tests and portable native DSP/project tests passed.
- Apple AU tests passed: 48 kHz mono/planar/packed Float32, 8,192-frame rendering,
  framework render-bridge agreement, AU-owned buffer reuse, undersized-buffer
  protection, silence-flag clearing and the 65,536-frame boundary.
- Standalone app and embedded extension compile passed.
- iPad simulator editor/fitting checks passed.
- The installed extension loaded out of process, returned an
  AUAudioUnitRemoteViewController and produced MIDI-driven audio (measured energy
  516.05). The host screenshot is retained in the CI artifact.
- Green workflow: https://github.com/diallo100x/instrument-dna-web/actions/runs/38444251299

Intermediate runs caught the SDK's default rejection of packed stereo bus formats
and an obsolete Swift rectangle logging function. The output-bus adapter and
supported logging fix were tested in the green run above. The actual Koala app
still requires device acceptance.

Implementation commits: `5ad00eb` (real extension host check), `80cfd46` (host buffer
formats/block sizes and component registration), `374628b` (negotiation/silence
flags), `3dfe2cb` (output-bus adapter), `c3bcff4` (logging and capacity checks).
