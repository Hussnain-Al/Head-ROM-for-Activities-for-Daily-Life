# Head range of motion during activities of daily living

Head movement in three anatomical planes during five activities of daily living,
measured with a smartphone strapped to the forehead.

## Scope and limits

Read this before the results.

- **One subject.** The author. This is a method demonstration and a measurement
  exercise, not a population study. No number here generalises.
- **One device, consumer grade.** A phone IMU on a forehead strap. Not a
  motion-capture reference, and not validated against one.
- **Three recordings per task**, with the phone refitted between them. Each
  recording carries its own neutral pose and its own head frame; they are never
  pooled at the sample level.
- **Axial rotation is the weakest channel.** It is integrated from the gyro, so
  it is the only channel that can drift. See below.

## Method

1. Resample gyro and accelerometer onto a uniform 50 Hz clock. This happens
   before any filtering, because `butter`/`filtfilt` assume even spacing and a
   phone log is not evenly spaced.
2. Low-pass the accelerometer at 0.5 Hz to recover the gravity direction.
3. Find the neutral hold: the stillest 2 s between 6 s and 22 s.
4. Build a head frame from that recording's own neutral gravity vector, so a
   refit between recordings does not leak flexion-extension into lateral bending.
5. Flexion-extension and lateral bending are the gravity vector expressed in that
   frame, low-passed at 5 Hz. Both are zero at neutral by construction.
6. Axial rotation is the vertical gyro component, bias-corrected against the
   neutral hold, low-passed, then integrated.
7. A common 180 s window is taken 2 s after the hold. Residual linear drift is
   removed from the yaw trace inside that window.
8. Range of motion is the 2.5–97.5 percentile range, which ignores single-sample
   spikes without ignoring real excursions.

Walking: stretches where the vertical gyro rate exceeds 25 deg/s are removed, as
those are the subject turning round at the end of a lap rather than head
movement. Axial rotation is not reported for walking at all.

## Drift, and why the yaw numbers can be believed at all

Integrating a MEMS gyro over 180 s without correction accumulates tens of degrees
of error, which lands directly in a percentile range. Two corrections are applied:
the bias measured during the neutral hold is subtracted before integration, and
the residual linear trend is removed from the windowed trace.

Removing the linear trend also removes any genuine net rotation across the
window. That is acceptable for the four stationary tasks, which are performed
facing one direction. It is not acceptable for walking, which is why walking is
excluded from this channel rather than corrected.

The drift removed from each trial is reported in `TableII_checks.csv`. If it
is large relative to the reported ranges, the yaw numbers should be treated as
indicative only.

## Diagnostics

Every trial reports four numbers, written to `TableII_checks.csv`:

| Column | What it checks |
|---|---|
| `fs_Hz` | the actual logged rate, against the assumed 50 Hz |
| `NoiseFloor_deg` | angular wobble while deliberately holding still |
| `GyroDrift_degPerS` | the linear rate removed from the yaw trace |
| `MountTilt_deg` | neutral pitch of the mount, so refit variation is visible |

A reported range smaller than a few multiples of the noise floor is not a
measurement.

## Recording setup

Sensor Logger v1.64 on Android, device 23129RAA4G, 20 ms sample interval
(50 Hz nominal, 49.9 Hz measured). Recorded 28 August 2026. The phone was held
on the forehead with a strap and refitted between recordings.

The repository stores the reproducible input set in `data/raw_data.zip`. On the
first run, the MATLAB script extracts `data/raw/` automatically. Each recording
folder contains `Gyroscope.csv`, `TotalAcceleration.csv` and `Metadata.csv`.
Sensor Logger also writes `Accelerometer`, the uncalibrated streams,
`Orientation` and `Annotation`; those are not included because the analysis does
not read them and keeping them would triple the repository size.

## Repeatability

Repeatability across the three recordings was limited, with the standard
deviation of flexion-extension range reaching 20-47% of the mean. These values
describe the scale of head motion during each task rather than serving as
reference values.

Tasks were performed naturally rather than to a fixed script, and three
recordings are too few to characterise that variation. Establishing reference
ranges would require a controlled protocol and more repeats per task.

## Running it

Requires MATLAB R2019b or later and the **Signal Processing Toolbox**
(`butter`, `filtfilt`). No Statistics Toolbox is needed.

```
data/raw/
  Calibration/
    Gyroscope.csv
    TotalAcceleration.csv
  Sitting/                     Sitting_2/    Sitting_3/
  Standing_working/            ...
  Scrolling_while_Standing/    ...
  Eating/                      ...
  Walking/                     ...
```

Each folder needs `Gyroscope.csv` and `TotalAcceleration.csv` with columns
`seconds_elapsed, x, y, z`. The included archive is extracted automatically.
Then:

```matlab
head_rom_analysis
```

Outputs `TableI_results.csv`, `TableII_checks.csv`, and `Fig1_traces.png`.

## Code map

One file, five parts. The `%%` section breaks fold in the MATLAB editor, so you
can collapse the whole thing to five lines and open what you need.

**Part 1 — Settings.** Everything tunable, in one block, before a single file is
opened.

- 1A signal tuning: 50 Hz clock, 5 Hz low-pass on the angles (above anything I
  can do on purpose), 0.5 Hz low-pass that leaves gravity behind.
- 1B time windows: 180 s analysis window, 2 s skipped after the hold, hold looked
  for between 6 s and 22 s and 2 s long.
- 1C axes and thresholds: 25 deg/s about vertical counts as turning round, sensor
  axis 3 points forward, sign flip so flexion reads positive.
- 1D files: data directory, the five task names, the walking flag, and the
  fifteen recording folders.

**Part 2 — Pipeline.** Calibration, then the loops, then the tables.

- 2A calibration: the maximum voluntary sagittal movement, which everything else
  is expressed as a percentage of. Stops with an error if the range comes out
  under 30 deg, because that means the axis or the sign is wrong.
- 2B preallocate: `rom`, `romSD`, `kept`, `curves`, `diags`.
- 2C loops: five tasks, three recordings each, each one handed to `readTrial`.
- 2D range per plane: `pctRange` on pitch, roll and yaw. Yaw is set to NaN for
  walking.
- 2E across recordings: mean and standard deviation of the three.
- 2F output: `TableI_results.csv`, the four checks printed to the console, and
  `TableII_checks.csv`.

**Part 3 — Figure.** A 5x3 grid, one row per task, one column per plane.

- 3A timeline and canvas.
- 3B the grid, indexed `(i-1)*3+p`.
- 3C walking yaw is greyed out rather than plotted.
- 3D each recording shifted onto its own median. The phone sat at a slightly
  different angle every time, so the height of a line means nothing and its
  spread means everything.
- 3E axes fixed at +/-16 deg and 0-180 s so the fifteen panels are comparable,
  then exported to `Fig1_traces.png`.

**Part 4 — `readTrial`.** Raw CSVs in, three columns of degrees out. This is
where all the corrections live.

- 4A load the gyro and accelerometer CSVs.
- 4B resample onto the uniform clock. This happens before any filtering, because
  `filtfilt` assumes even spacing and a phone log is not evenly spaced.
- 4C low-pass the accelerometer and normalise to get the gravity direction.
- 4D find the neutral hold, then re-zero the clock on it.
- 4E build a head frame from that recording's own neutral gravity vector, so a
  refit between recordings cannot leak flexion-extension into lateral bending.
  Also records how crooked the phone sat.
- 4F pitch and roll: gravity in that frame, `atan2d`, low-passed. Both are zero
  at neutral by construction.
- 4G yaw: vertical gyro component, bias measured at the hold subtracted, then
  integrated with `cumtrapz`.
- 4H cut the common window, then remove the residual linear drift from the yaw
  trace.
- 4I walking only: NaN out the stretches spent turning round, and report how much
  of the recording survived.

**Part 5 — `pctRange`.** Sort, drop NaN, subtract the 2.5% index from the 97.5%
index. Written out so the script does not pull in the Statistics Toolbox for one
line.

## Sign and axis conventions

Set in the config block at the top:

- `axFwd` — the sensor axis pointing anteriorly out of the phone screen.
- `sgnFlex`, `sgnBend` — sign flips so that flexion and left lateral bending are
  positive.

Both are validated by the calibration trial, which is a maximum voluntary
sagittal movement. If the calibration sagittal range comes out implausibly small,
the script stops rather than reporting nonsense.
