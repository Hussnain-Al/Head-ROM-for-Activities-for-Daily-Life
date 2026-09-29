# Head ROM during activities of daily living

A single-participant feasibility study using a forehead-mounted smartphone IMU to estimate head ROM during seated laptop work, standing laptop work, standing phone use, eating, and level walking.

For study details, see the [feasibility report (PDF)](Head_Movement_ADL_Feasibility_Report.pdf). **The linked PDF is an earlier version:** it still uses the removed 2 s delay, older results and older figure captions. The current code, CSV tables and preview figures use the 180 s window immediately after the neutral hold. The PDF URL is unchanged.

![Five recorded activities](task_setup.png)

![Head-angle traces, including walking axial rotation](Fig1_traces.png)

![Trial head ROM by task and plane](Fig2_flexext_statistics.png)

## Run

Requires MATLAB R2019b or later and Signal Processing Toolbox. Open MATLAB in the repository root, then run the command below. The script extracts `data/raw_data.zip` when `data/raw/` is absent. The dataset contains 15 task recordings and one calibration recording.

```matlab
head_rom_analysis
```

The main analysis uses one fixed parameter set:

| Setting | Selected value |
|---|---:|
| Resampling rate | 50 Hz |
| Gravity cutoff | 0.5 Hz |
| Yaw-rate cutoff | 5 Hz |
| Neutral hold | Quietest complete 10 s block in the first 30 s |
| Task window | 180 s, beginning immediately after the neutral hold |
| Walking-turn threshold | 25 deg/s* |

*Turn-threshold effect: 20 deg/s produced 11.94 deg mean walking flexion-extension ROM with 69.63% retained; 25 deg/s produced 11.70 deg with 76.97% retained; and 30 deg/s produced 11.70 deg with 77.79% retained. Across these three tested thresholds, mean walking flexion-extension ROM differs by 0.25 deg and retention by 8.16 percentage points. This sensitivity check does not establish turn-detection accuracy. The threshold is angular speed, not the 180 deg angle of a lap turn.

## Processing

`readHeadTrial.m` reads one recording, measures its timestamp rate, interpolates gyroscope and acceleration channels onto the same uniform 50 Hz clock, identifies the neutral hold, defines the head reference frame, and returns three angle channels. The 0.5 Hz gravity estimate provides flexion-extension and lateral bending. Gyroscope bias is estimated during the selected neutral hold, subtracted, and the yaw rate is filtered and integrated for axial rotation. Both filters are second-order Butterworth designs applied forward and backward with `filtfilt`; this removes phase delay and squares the single-pass magnitude response. The listed cutoffs are design values, not independently validated settings for this phone.

Head ROM is calculated as:

```text
97.5th percentile - 2.5th percentile
```

This summarizes the central 95% of the angle distribution; it is not maximum-minus-minimum ROM and does not prove that the excluded extremes are artefacts. Mean, sample SD, variance, and CV are calculated across the three trial-level flexion-extension ROM values. Flexion-extension and lateral traces use the neutral reference; axial traces have a fitted linear trend removed. No trace is median-centred. Detrending removes a fitted straight line from the integrated angle; it cannot distinguish sensor drift from genuine slow rotation. The neutral search minimizes mean gyroscope magnitude, so a quiet period is not automatically a verified neutral posture.

Walking consists of straight paths separated by approximately 180 deg direction changes. Samples within approximately 1 s of an absolute yaw rate exceeding 25 deg/s are excluded from the straight-walking calculations to reduce abrupt changes at lap turns. The complete detrended walking axial-angle trace, including turns, appears in Figure 1. Walking axial ROM is not reported because a single head sensor cannot separate head motion from whole-body rotation during lap turns.

## Current results

Values below are across three trial ROM values per task, from `TableI_results.csv`.

| Task | Flexion-extension mean ± SD (deg) | CV (%) |
|---|---:|---:|
| Seated laptop | 12.4 ± 7.0 | 56 |
| Standing laptop | 9.9 ± 3.6 | 36 |
| Standing phone | 19.6 ± 8.9 | 45 |
| Eating | 13.3 ± 3.0 | 22 |
| Walking, retained segments | 11.7 ± 4.4 | 37 |

The CSV reports mean and SD for lateral bending and non-walking axial rotation too. **Variance and CV are currently calculated only for flexion-extension.** This is an output limitation, not a restriction on calculating CV for the other planes. Walking axial ROM is deliberately set to missing. CV is `100 × sample SD / mean ROM`; sample SD uses `n−1 = 2`. Values are calculated before rounding. These are descriptive within-participant statistics, not accuracy estimates.

## Outputs

- `TableI_results.csv` — mean and SD for all three head ROM planes, flexion-extension variance and CV, and retained data
- `TableII_checks.csv` — per-trial sampling rate, neutral-hold SD, yaw trend, and neutral phone inclination
- `Fig1_traces.png` and `Fig1_traces_updated.svg` — 180 s head-angle traces, including walking axial rotation with its lap turns
- `Fig2_flexext_statistics.png` — one box per task in each plane, with solid task colors and black outlines. The centre line is the median; boxes span the quartiles and whiskers span the minimum and maximum. Each trial ROM is its 97.5th minus 2.5th percentile angle. Boxes summarize just three values, so interpret them descriptively. Walking axial angles appear in Figure 1, but walking axial ROM is excluded from Figure 2 because lap turns include whole-body rotation. Mean, SD, variance, and CV remain in `TableI_results.csv`.

The quality table records diagnostics, not pass/fail evidence of accuracy: measured rate is `1 / median(timestamp interval)` before resampling; neutral-hold SD combines stillness and measurement variability; yaw trend is the removed slope; phone inclination describes the neutral mounting/posture angle. `Kept_pct` is the mean of `100 × retained samples / window samples` across each task’s three trials.

## Separate sensitivity checks

Parameter sensitivity is kept outside the main analysis:

```matlab
run('validation/validate_gravity_cutoff.m')
run('validation/validate_turn_threshold.m')
```

The gravity validation compares 0.3, 0.5, and 1.0 Hz. The turn validation compares 20, 25, and 30 deg/s. These values are not additional settings in the main analysis; they test whether nearby choices materially change the result. Outputs are `TableIII_gravity_sensitivity.csv` and `TableIV_turn_sensitivity.csv`. Across 0.3–1.0 Hz, the largest within-task change in mean flexion-extension ROM is 0.99 deg (eating); that does not establish angle accuracy or preservation of faster motion.

## Limits

This is a one-participant method demonstration using a consumer smartphone and three trials per task. It was not validated against optical motion capture and does not provide clinical or population reference values. Unscripted movement and mount refitting may contribute to trial variability; their effects were not measured separately. A single head sensor measures head orientation in space and cannot separate head motion from trunk motion. The 0.5 Hz gravity filter attenuates faster movements, and yaw detrending can remove genuine slow rotation.

The committed tables and previews were regenerated with an independent Python reproduction. The revised MATLAB scripts have not yet been runtime-tested in MATLAB. The separate validation files are parameter-sensitivity checks, not validation against a reference instrument.

## References

- D. Demaree, J. Brignone, M. Bromberg, and H. Zhang, [“Preliminary Study on Effects of Neck Exoskeleton Structural Design in Patients With Amyotrophic Lateral Sclerosis,”](https://doi.org/10.1109/TNSRE.2024.3397584) *IEEE Transactions on Neural Systems and Rehabilitation Engineering*, 2024.
- A. R. Weston et al., [“Head and Trunk Kinematics during Activities of Daily Living with and without Mechanical Restriction of Cervical Motion,”](https://doi.org/10.3390/s22083071) *Sensors*, 2022. The study used a 6 Hz low-pass Butterworth filter; it does not directly validate this project’s 5 Hz choice.
- V. T. van Hees et al., [“Separating Movement and Gravity Components in an Acceleration Signal and Implications for the Assessment of Human Daily Physical Activity,”](https://doi.org/10.1371/journal.pone.0061691) *PLOS ONE*, 2013. The study evaluated 0.2 and 0.5 Hz cutoffs for gravity separation; it does not validate this project’s head-angle estimates.
- [Android sensor coordinate system and sampling guidance](https://developer.android.com/develop/sensors-and-location/sensors/sensors_overview#sensors-coords).
