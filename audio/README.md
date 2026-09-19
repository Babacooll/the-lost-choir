# audio/

Slice-scoped audio for The Lost Choir's first vertical slice.

- **Direction and production rules:** `docs/audio/AUDIO_BIBLE.md`
- **Runtime/FMOD contract:** `docs/audio/fmod-implementation-contract.md`
- **Generator:** `tools/audio/synth_slice_audio.py` (numpy only)

## reference/

48 kHz / 16-bit / stereo WAV. Regenerate with:

```
python3 tools/audio/synth_slice_audio.py audio/reference
```

The render is deterministic — a fixed RNG seed means re-running reproduces every byte, and
`reference/MEASUREMENTS.json` is a regression test for the timing, spectral and level contracts,
not a one-off report. Run it whenever a cue changes.

**Status: reference / temp-track.** No vocal-synthesis, sample-library, recording or
generative-audio capability was available, so sung material is a synthetic approximation. It
carries the timing, spectral and level contract exactly; it does not carry a singer. See
`AUDIO_BIBLE.md` §1 before describing these assets anywhere.

**Provenance and licensing:** entirely original deterministic synthesis. No third-party audio, no
samples, no model output, no recorded performance. The script is the provenance record.
