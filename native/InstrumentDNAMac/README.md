# Instrument DNA · native Mac AUv3 + standalone 0.4.3

A native AppKit/SwiftUI Mac instrument using the same C DSP, analyzer, fifteen
factory presets, Reflection format and 45 AU parameters as the iPad build.
macOS 12 or later; Release builds include Apple Silicon and Intel architectures.
The iPad project and iOS 15.4 deployment floor remain separate and unchanged.

The optional coupled-body bank adds vibes, marimba, xylophone, plate/bell,
membrane/shell, plucked string/body and an experimental air pipe. The previous
eight presets are unchanged. Physical model exposes four added body controls;
AU parameter addresses 0–40 retain their original meanings.

## Build and use in DBAL DAW

Keep both `native/InstrumentDNAMac` and `native/InstrumentDNA` directories together.
Open `InstrumentDNAMac.xcodeproj`, select **InstrumentDNAMac**, choose your Mac,
set your signing team for both targets, then Run. The containing Mac app embeds
`InstrumentDNAMacInstrument.appex`; do not run the extension target alone.
Move the built containing app to `/Applications` and launch it once. Keep that
app installed: it contains the AUv3. Restart DBAL DAW so its plug-in list refreshes.
No `.component` file needs copying into Audio/Plug-Ins for this AUv3.

In DBAL's native Mac view, select a MIDI/instrument track, choose **AU Instrument…**,
then **Diallo Beats Audio Lab: Instrument DNA**. Open **Instrument UI** to access
module pages and choose Scalar Guitar or another factory model under Instrument
map. Play using DBAL's keyboard, MIDI clips or a MIDI controller. Load this as an
instrument, not an insert effect. Save the DBAL project to retain AU state.

The current DBAL Pocket Studio package's Mac picker searches `aumu` components,
loads them using `AVAudioUnit.instantiate`, opens custom NSViewController editors,
sends scheduled MIDI and saves full AU state. Instrument DNA implements that
contract. Automated acceptance additionally tests a shipped out-of-process AUv3
through instrument → track mixer → master offline rendering. This topology matches
DBAL's Mac host; it is not a completed end-to-end session test in the DBAL app.
Retest actual DBAL playback, UI, save/reopen and rendering on your Mac.

## Controls

All existing module pages, note review, extraction, fitting, layer assignment,
model import/export, macros, XY, Era and guitar controls share the native iPad
implementation. Mouse-play piano/mallet/fretboard/pad layouts. Click the playing
surface to focus A W S E D F T G Y H U J K; drag horizontally for pitch bends.
External MIDI/MPE supports polyphony and independent member-channel bends.
A mouse controls one dragged note; the Mac does not emulate iPad multitouch.
Output provides instrument checks; standalone also provides Recover audio.
Branding remains “a product of Diallo Beats Audio Lab” in the bottom-right.

## Terminal build

From the repository/package root:

```sh
xcodebuild -project native/InstrumentDNAMac/InstrumentDNAMac.xcodeproj \
  -scheme InstrumentDNAMac -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath Build/InstrumentDNAMac build
```

Output: `Build/InstrumentDNAMac/Build/Products/Release/InstrumentDNAMac.app`.
Use Xcode's signing settings first. The source ZIP is not a notarized installer.
CI uses local ad-hoc signing only for automated tests, not distribution signing.

`python3 generate_project.py` regenerates the checked-in project. Shared source
files are referenced directly; no parallel copy of the DSP or model is maintained.
Native reconstruction and time-stretching limitations remain as described in the
iPad README. No third-party modeling framework or source recording is bundled.
