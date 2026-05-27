<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This chip implements a hardware accelerator for the Collatz conjecture.
Given a 16-bit starting number n, it iterates the accelerated Collatz
sequence each clock cycle and outputs the stopping time - the number of
steps taken to reach 1.

Two optimizations are made into this hardware:
- **Odd n**: computes (3n+1)/2 in a single cycle (two logical steps)
- **Even n**: strips all trailing zeros at once using a priority encoder
  and barrel shifter (up to 8 halvings per cycle)

Internal registers are 24-bit to safely accommodate trajectory peaks
which can reach ~100× the 16-bit input value.

## How to test

1. Load the low byte of n via `ui_in` with `uio_in[0] = 0`
2. Load the high byte of n via `ui_in` with `uio_in[0] = 1`
3. Pulse `uio_in[1]` (start) high for one cycle
4. Wait for `uio_out[2]` (done) to go high
5. Read stopping time from `uo_out[7:0]`

Known values for verification:
- n=27  → 111 steps (famous long trajectory, peaks at 9232)
- n=871 → 178 steps

