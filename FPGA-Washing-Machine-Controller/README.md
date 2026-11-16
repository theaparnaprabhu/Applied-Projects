# FPGA Washing Machine Controller (Verilog, Real Digital Boolean Board)

A finite-state-machine washing machine controller on a Spartan-7 FPGA. It runs a
Fill → Wash → Rinse → Spin cycle (5 / 10 / 8 / 6 s), pauses and resumes with the
door switch, and shows stage and time left on a multiplexed seven-segment display.

**Target:** Real Digital Boolean Board (XC7S50-CSGA324), 100 MHz clock
**Tools:** Verilog HDL, AMD Vivado
**Course:** 25ECE201, NMAM Institute of Technology, Nitte

## Features
- 6-state FSM: IDLE, FILL, WASH, RINSE, SPIN, DONE
- Start (BTN0) accepted only in IDLE with the door closed; ignored while running
- Reset (BTN1) returns to IDLE from any state
- Door open (SW0 = 1) freezes the countdown, including the partial second. Closing resumes exactly where it stopped
- Display: `----` idle, `<stage> <secs>` while running (e.g. `1 05`), `End` when done
- LED0–LED3 show the active stage, LED15 shows door open, LED0–LED3 blink at 2 Hz in DONE
- All timing from enable pulses on a single 100 MHz clock (no derived clocks)

## Architecture
```
 100 MHz clk ─► clock_divider ──tick_1khz──► debouncer x2 ─► (start_p, reset_p) ─┐
                 ▲   │  │                                                         ▼
          sec_en │   │  └─tick_1hz, tick_4hz ───────────────────────────────► wash_ctrl (FSM)
          sec_clr└───┼──────────────────────────────────────────────────────────  │  │
                     └─tick_1khz─► display_mux ◄── d3..d0 (codes) ◄───────────────┘  └─► LEDs
                                       └─► seg7_decoder ─► seg / an / dp
```

| Module | Role |
|---|---|
| `clock_divider` | 1 kHz and 4 Hz free-running enables; **gated** 1 Hz enable (`sec_en`, `sec_clr`) |
| `debouncer` | 2-FF synchroniser, 15 ms filter, rising-edge pulse |
| `wash_ctrl` | FSM, seconds countdown, door synchroniser, display codes, LED logic |
| `display_mux` | Scans 4 digits at 250 Hz, inverts for active-low lines |
| `seg7_decoder` | Code → segment pattern (digits, `-`, E, n, d, blank) |
| `washer_top` | Structural top; ties off the unused left display |

## Design details

### Timing (N = f_clk / f_out, counted 0 … N−1)
| Pulse | Count | Use |
|---|---|---|
| 1 kHz | 100,000 | display scan, debounce, 1 ms base |
| 1 Hz | 100,000,000 | stage countdown |
| 4 Hz | 25,000,000 | blink toggle (0.25 s ON + 0.25 s OFF = 2 Hz) |

Counters are 27 bits (2^27 = 134,217,728 > 100,000,000). Each tick is one clock wide.

### Pause and resume
The FSM has no separate "paused" state. It drives `sec_en = running & ~door` into the
divider, and the 1 Hz counter **holds** when `sec_en = 0`. Because the counter keeps its
value, a pause never adds or loses time, even mid-second. `sec_clr` clears the counter
in IDLE and DONE so each run starts with a full first second.

### Debouncing
Button → two flip-flops (metastability) → counter that accepts a new level only after
15 consecutive 1 ms ticks → `press = stable & ~prev` for one pulse per press.
`T_debounce = 15 × 1 ms = 15 ms`.

### Display
Digits are scanned for 1 ms each, so `f_refresh = 1 / (4 × 1 ms) = 250 Hz`.
Segment and digit-select lines on this board are active-low, so the multiplexer inverts
the decoder's active-high output.

## Verification
`sim/tb_wash_ctrl.v` tests the core FSM with a **scaled time base**: the divider is
replaced by a fast model where 1 s = 20 clocks, so a 29 s cycle simulates in a few µs.
Self-checking tests print PASS/FAIL for: power-on idle, start ignored with door open,
`1 05` with LED0, start ignored while running, `2 10` with LED1, pause with door open,
resume, `End` display, 2 Hz LED blink, reset in DONE, reset during a running stage, and a
clean restart.

## Results
- Simulation: all checks PASS 
- Synthesis/implementation: 
- Hardware: verified on the board : idle `----`, running `2 09`, done `End`

## Pin map (from Real Digital's board file)
| Signal | Pin | Signal | Pin |
|---|---|---|---|
| clk | F14 | LED0–LED3 | G1, G2, F1, F2 |
| BTN0 / BTN1 | J2 / J5 | LED15 | A4 |
| SW0 (door) | V2 | right display digits | H3, J4, F3, E4 |


## Build and run
1. Create a Vivado RTL project for XC7S50-CSGA324.
2. Set `washer_top` as top. Run synthesis, implementation, generate bitstream.
3. Program via Hardware Manager. To simulate, set `tb_wash_ctrl` as the simulation top and run `run all`.

## Demo sequence
BTN0 → `1 05` (LED0) → `2 10` (LED1). Raise SW0 during wash: count freezes, LED15 on.
Lower SW0: it continues. After 29 s of running time: `End`, LEDs blink. BTN1 → `----`.

## Limitations and future work
- Stage durations are compile-time constants (`localparam` in `wash_ctrl.v`)
- The countdown is a binary value split into tens/ones, not a BCD counter
- The door switch is synchronised but not debounced (it is a slide switch)
- Future: selectable programs, buzzer on completion, water-level input

## AI use
I used an AI assistant while developing this project: for drafting module structure,
explaining concepts, and reviewing code. I then read and traced each module, ran the
simulation and synthesis myself, tested the design on the board, and can explain and
modify every part of it. Design choices (enable pulses, gated 1 Hz counter) are
documented above.
