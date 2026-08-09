# MazeRunner — FPGA Maze-Solving Robot

MazeRunner is a hardware-first autonomous robot controller written in SystemVerilog for **ECE 551**. It runs on an Intel/Altera Cyclone IV E FPGA and brings together sensor acquisition, inertial heading estimation, PID steering, motor PWM, UART commands, and a simple maze-solving state machine.

The interesting part of this project was not any one peripheral—it was getting the whole closed loop to behave. The controller reads the maze with IR sensors, tracks heading from an inertial sensor, adjusts two motors independently, and decides when to stop, turn, or continue until it reaches a magnetic finish marker.

## What it does

- Accepts commands over UART/Bluetooth for calibration, heading changes, motion, and autonomous solve mode.
- Samples IR distance sensors and battery voltage through an SPI ADC.
- Interfaces with an inertial sensor over SPI, calibrates its heading, and integrates motion only when the robot is moving.
- Uses a PID loop to convert heading error into differential left/right motor commands.
- Applies IR-based heading fusion while moving to keep the robot centered in a corridor.
- Detects left/right/forward openings, ramps speed up and down, and chooses the next turn in autonomous mode.
- Detects the maze goal with a Hall-effect sensor and plays a piezo fanfare on completion.

## Architecture

```text
 UART / BLE ──> command processor ─┐
                                  ├──> navigation FSM ──> PID ──> motor PWM
 maze solver ─────────────────────┘         ▲               │
                                            │               ▼
 IR + ADC ──> sensor interface ──> IR fusion         differential drive
                                            │
 IMU / gyro ──> inertial interface ────────┘
                         │
 Hall sensor ────────────┴──> solve complete / piezo fanfare
```

The top-level integration point is [`ProjectDir/MazeRunner.sv`](ProjectDir/MazeRunner.sv). It selects between manual-command and autonomous-solver requests, then connects the navigation and control path to the physical I/O.

## Design highlights

**Closed-loop steering.** The PID controller combines proportional, integral, and derivative terms from a signed heading error and creates complementary left/right speed commands. Motor output is suppressed whenever navigation is not actively moving.

**Deliberate motion control.** The navigation FSM starts from a minimum drive level, accelerates to a capped forward speed, and uses a gentler stop for a detected side opening or a faster stop for a blocked path. Heading moves complete only after the controller settles within tolerance.

**Practical sensor fusion.** IR corrections are enabled only after the robot is moving at a meaningful speed. This avoids reacting to noisy distance readings while starting, stopping, or turning in place.

**Autonomous maze policy.** `maze_solve` drives forward until an opening or obstruction is encountered, prefers a commanded side when both choices exist, otherwise takes the available side, and turns around at a dead end. The Hall sensor ends the solve sequence.

**Timing-aware RTL.** The top level contains explicit pipeline registers between IR fusion and PID, and between PID and the motor driver, breaking up long control-path combinational logic before synthesis.

## Verification

The repository includes directed, self-checking full-system testbenches with behavioral robot and peripheral models:

- [`MR_all_tests_tb.sv`](ProjectDir/MR_all_tests_tb.sv) exercises reset behavior, calibration, east/west turns, UART acknowledgements, and forward acceleration.
- [`MazeRunner_synth_regression_tb.sv`](ProjectDir/MazeRunner_synth_regression_tb.sv) repeats the key checks against the synthesis-oriented integration flow.
- Supporting models such as `RunnerPhysics`, `RemoteComm`, SPI device models, and inverse-PWM helpers let the controller be evaluated as a system rather than as isolated blocks.

The testbenches check observable behavior—not just internal states—including known outputs after reset, wheel polarity during turns, heading direction and settling range, command acknowledgements, and forward wheel acceleration.

## Repository guide

| Location | Contents |
| --- | --- |
| [`ProjectDir/`](ProjectDir) | Primary SystemVerilog RTL, testbenches, and Intel Quartus project files. |
| [`ProjectDir/MazeRunner.sv`](ProjectDir/MazeRunner.sv) | Top-level controller and subsystem integration. |
| [`ProjectDir/maze_solve.sv`](ProjectDir/maze_solve.sv) | Autonomous maze-solving finite-state machine. |
| [`ProjectDir/navigate.sv`](ProjectDir/navigate.sv) | Heading/move sequencing, speed ramping, and opening detection. |
| [`ProjectDir/PID.sv`](ProjectDir/PID.sv) | Differential-drive heading controller. |
| [`project_synthesis/`](project_synthesis) | Synopsys synthesis netlists, reports, and supporting collateral. |
| [`ProjectSpec.pdf`](ProjectSpec.pdf) | Original project specification. |

## Building and running

1. Open `ProjectDir/MazeRunner.qpf` in Intel Quartus Prime (the project targets a **Cyclone IV E EP4CE22F17C6**).
2. Compile with `MazeRunner` as the top-level entity. Pin assignments and source-file inclusion are captured in `MazeRunner.qsf`.
3. For simulation, compile the RTL with its behavioral support models in ModelSim/Questa and run a self-checking testbench such as `MR_all_tests_tb`.

The checked-in synthesis directory is useful for reviewing the ASIC-oriented synthesis work, but it is collateral rather than the source of truth; the RTL in `ProjectDir/` is the design to modify.

## Tech stack

SystemVerilog · Intel Quartus Prime · ModelSim/Questa-style simulation · Synopsys Design Compiler collateral · SPI · UART · PWM · PID control · FPGA prototyping

---

Built as a final project for ECE 551. This repository is a snapshot of an academic hardware project and includes generated build and synthesis artifacts alongside the source RTL.
