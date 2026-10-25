# Web audio recovery — 0.8.2

The user reported that the direct test tone plays but Scalar Guitar is silent.
Chromium and WebKit acceptance on the previous live-model code both passed; the
specific user-session failure has not been reproduced. This patch adds an
independent, testable recovery path rather than claiming the underlying device
failure is diagnosed.

- **Compatibility audio** renders the loaded physical/guitar model into a cached
  AudioBuffer and plays it directly, bypassing AudioWorklet voice and room nodes.
  It retains the authored pickup, harmonics/phases, tuning, velocity, selected
  articulation, vibrato, body/drive and rendered room. It does not substitute a
  generic oscillator or require source audio.
- **Recover instrument audio** resumes audio, enables compatibility mode and
  auditions the loaded model. With no model loaded it gives a load instruction.
- Failed worklet module initialization automatically uses rendered playback.
  A voice processor error switches subsequent/retriggered notes to compatibility;
  a room processor error bypasses the failed room instead of silencing output.
- `?preset=scalar-guitar&compat=1` opens the factory preset in compatibility mode;
  the user still clicks Pluck target or a key to start sound.
- Fresh 0.8.2 dependency and factory URLs avoid reusing earlier cached modules.

Compatibility mode renders a natural five-second note. Early note release still
fades/stops it; fixed note length fades at the selected duration. Controls apply
to new notes. It cannot keep a live modeled voice through legato: transitions
render a new note/slide. The normal AudioWorklet backend remains available with
Compatibility audio unchecked. This is a browser-only patch; native 0.4.1 is
unchanged.

The web app uses local Web Audio/DSP and requires no OpenAI API key, credits or
subscription to generate these sounds. ChatGPT Work usage applies to development
assistance, not to the instrument's playback engine.
