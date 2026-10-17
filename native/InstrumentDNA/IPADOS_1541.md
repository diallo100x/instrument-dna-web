# Instrument DNA 0.3.2 (build 6) — iPadOS 15.4.1

This compatibility patch keeps the 0.3.1 instrument and AUv3 host-format work.
The existing 15.4 deployment floor already includes 15.4.1; this release does not
claim to fix a reproduced 15.4.1 runtime failure. No sound-engine or preset-format
changes are required by the source audit.

## Install

1. On a Mac, unzip and open `InstrumentDNA.xcodeproj` in Xcode.
2. Select **InstrumentDNA**, not InstrumentDNAInstrument.
3. Set your signing team on both targets; keep the existing bundle identifiers
   where possible to update the installed app and preserve its identity.
4. Choose the connected iPad running 15.4.1 and click Run. Launch standalone once.
5. Close and reopen the AUv3 host and insert a fresh Instrument DNA instance.

The project and both targets inherit iOS 15.4 as their minimum. Do not raise it
to the SDK version or the Mac's OS version. A modern Xcode SDK can build an app
with an older deployment minimum; device deployment still depends on the Xcode
installation supporting that connected device. This archive is source, not a
signed IPA or a binary that can be installed directly from Files.

## Compatibility safeguards

- Regression checks cover Debug/Release deployment floors, synchronized app and
  extension version/build numbers, embedded extension and stable AU identifiers.
- Unguarded availability warnings are errors in Objective-C/C++; Swift already
  rejects unguarded calls to APIs newer than the deployment minimum.
- CI compiles a Release iOS device build and checks MinimumOSVersion in both
  built bundles, alongside existing simulator, DSP and remote-AUv3 tests.
- Component version increments to refresh host registration; no bundle-ID change.

## Device acceptance still required

No iPadOS 15.4.1 device is available in the build environment. A current simulator
does not establish older-device runtime behavior or a Koala fix. On the iPad,
check standalone factory sound, multitouch and page navigation, cropped audio
import/extraction, source/model previews, named save/reload and MIDI. Then check
the AUv3 editor, sound and session recall in a host version that itself supports
15.4.1. Send any Xcode error or crash report if a step fails.
