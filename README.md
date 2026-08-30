# Head ROM during activities of daily living

A single-participant feasibility study using a forehead-mounted smartphone IMU to quantify head movement during five activities: seated laptop work, standing laptop work, standing phone use, eating, and level walking.

![Five recorded activities](task_setup.png)

## Project contents

- Three trials per activity plus one calibration recording
- Fixed 180 s analysis windows at 50 Hz
- Flexion-extension, lateral bending, and axial rotation estimates
- Straight-walking analysis with lap turns excluded
- Reproducible MATLAB code, raw inputs, results tables, and plots

## Run in MATLAB

Requires MATLAB R2019b or later and Signal Processing Toolbox.

```matlab
head_rom_analysis
```

The script extracts `data/raw_data.zip` automatically on the first run and generates:

- `TableI_results.csv` — task-level range-of-motion results
- `TableII_checks.csv` — sampling, noise, drift, and mount checks
- `Fig1_traces.png` — all processed 180 s movement traces

## Results preview

![Processed head-angle traces](Fig1_traces.png)

## Processing summary

Gyroscope and acceleration data are resampled to 50 Hz. Gravity is isolated with a 0.5 Hz low-pass filter, head angles are filtered at 5 Hz, and each trial is referenced to its own neutral hold. Range of motion is calculated from the 2.5th-97.5th percentile span. During walking, high-yaw-rate lap turns are removed and axial rotation is not reported.

## Limits

This is a one-participant method demonstration using a consumer smartphone sensor. It was not validated against optical motion capture and does not provide clinical or population reference values. Axial rotation is the least reliable channel because it depends on integrated gyroscope data.

## References

- D. Demaree, J. Brignone, M. Bromberg, and H. Zhang, [“Preliminary Study on Effects of Neck Exoskeleton Structural Design in Patients With Amyotrophic Lateral Sclerosis,”](https://doi.org/10.1109/TNSRE.2024.3397584) *IEEE Transactions on Neural Systems and Rehabilitation Engineering*, 2024.
- [Sensor Logger documentation](https://www.tszheichoi.com/sensorloggerhelp), including its [coordinate-system](https://github.com/tszheichoi/awesome-sensor-logger/blob/main/COORDINATES.md) and [units](https://github.com/tszheichoi/awesome-sensor-logger/blob/main/UNITS.md) references.
