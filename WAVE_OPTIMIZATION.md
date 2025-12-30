# Wave Optimization Spec (macOS)

## 0. Goal
Improve the floating wave visualization:
- Always flows left -> right (no backflow).
- Volume drives amplitude (quiet -> small, loud -> tall).
- Beats feel like mini-climax spikes (sharp + higher).
- Silence stays calm with subtle breathing.

## 1. Inputs
Per-frame inputs (0..1):
- rms_raw: overall energy
- low_raw: low-frequency energy

Outputs:
- rms_s: smoothed rms (0..1)
- low_s: smoothed low (0..1)
- beat: transient accent (0..1)
- climaxLevel: section-level boost (0..1)
- isClimax: hysteresis state (bool)

## 2. Noise Floor
Parameters:
- NF_ALPHA = 0.995
- NF_MARGIN = 0.015
- NF_FREEZE_RMS = 0.03

Update:
- if rms_raw < NF_FREEZE_RMS:
    nf = NF_ALPHA*nf + (1-NF_ALPHA)*rms_raw
  else:
    nf = nf (freeze)
- nf2 = nf + NF_MARGIN

## 3. Normalize + Compress (RMS as primary)
Parameters:
- RMS_GAIN = 3.0, LOW_GAIN = 2.2
- GAMMA_RMS = 0.60, GAMMA_LOW = 0.70

Formulas:
- rms1 = clamp((rms_raw - nf2) * RMS_GAIN, 0, 1)
- low1 = clamp((low_raw - nf2) * LOW_GAIN, 0, 1)
- rms2 = pow(rms1, GAMMA_RMS)
- low2 = pow(low1, GAMMA_LOW)

## 4. Attack/Release Smoothing
Parameters:
- ATTACK_MS_RMS = 60, RELEASE_MS_RMS = 320
- ATTACK_MS_LOW = 35, RELEASE_MS_LOW = 220

alpha(ms) = exp(-dt / (ms/1000))

smooth(prev, x, a_attack, a_release):
- a = (x > prev) ? a_attack : a_release
- return a*prev + (1-a)*x

Compute:
- rms_s = smooth(rms_s, rms2, alpha(ATTACK_MS_RMS), alpha(RELEASE_MS_RMS))
- low_s = smooth(low_s, low2, alpha(ATTACK_MS_LOW), alpha(RELEASE_MS_LOW))

## 5. Beat Accent (Transient)
Parameters:
- BEAT_DIFF_GAIN = 2.4
- BEAT_RMS_RATIO = 0.65
- BEAT_GATE = 0.08

Formulas:
- low_diff = max(0, low_s - low_s_prev)
- rms_diff = max(0, rms_s - rms_s_prev)
- beat_raw = max(low_diff * BEAT_DIFF_GAIN, rms_diff * BEAT_DIFF_GAIN * BEAT_RMS_RATIO)
- beat = clamp(pow(beat_raw, 0.8), 0, 1)
- if rms_s < BEAT_GATE: beat = 0

## 6. Climax Detection (Section + Beat Override)
Window:
- WIN_SEC = 0.8

Energy:
- energy = max(rms_s, low_s * 0.85)

Stats:
- mean = mean(energy over WIN_SEC)
- peak = max(energy over WIN_SEC)

Normalize:
- m = clamp((mean - 0.35) / 0.50, 0, 1)
- p = clamp((peak - 0.55) / 0.35, 0, 1)
- climax_raw = 0.70*m + 0.30*p

Beat override:
- climax_in = max(climax_raw, beat)

Climax smoothing:
- CLIMAX_ATTACK_MS = 180
- CLIMAX_RELEASE_MS = 700
- climaxLevel = smooth(climaxLevel, climax_in, alpha(CLIMAX_ATTACK_MS), alpha(CLIMAX_RELEASE_MS))

Hysteresis:
- HYST_ON = 0.60, HYST_OFF = 0.45
- OFF -> ON if climaxLevel > HYST_ON
- ON -> OFF if climaxLevel < HYST_OFF

## 7. Visual Mapping (Amplitude + Sharpness)
Parameters:
- AMP_BASE = 0.06, AMP_GAIN = 0.65
- LOW_BOOST = 0.30
- CLIMAX_BOOST = 0.85
- BEAT_AMP = 0.25
- SHARP_BASE = 0.15, SHARP_BEAT = 0.70

Mapping:
- baseAmp = AMP_BASE + AMP_GAIN * rms_s
- lowLift = 1.0 + LOW_BOOST * low_s
- climaxLift = 1.0 + CLIMAX_BOOST * climaxLevel
- beatLift = 1.0 + BEAT_AMP * beat
- A = baseAmp * lowLift * climaxLift * beatLift
- sharp = SHARP_BASE + SHARP_BEAT * beat

Direction:
- Always move left -> right using phase = k * (x - v * t)
- v is constant (no beat-driven speed changes)

## 8. Acceptance Tests
- EDM strong bass: beat spikes visible, climax rises during drop, wave always moves right.
- Classical light: waves subtle, no over-reaction.
- Pause/silence: amplitude approaches near-zero within 2s, no jitter.
- Frequent track changes: UI stable, no crash.

## 9. Agent Tasks
1) Implement pipeline above as FeaturePipeline and expose tuning.
2) Update WaveRenderer to use A/sharp and constant rightward flow.
3) Keep debug overlay toggle for rms_s/low_s/beat/climaxLevel.
4) Ensure CPU < 5% and no visible flicker.
