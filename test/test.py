# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def load_and_run(dut, n, expected):
  """Load a 16-bit value, run Collatz, assert the stopping time."""

  # ── Load low byte ─────────────────────────────────────────────────
  await RisingEdge(dut.clk)
  dut.ui_in.value  = n & 0xFF
  dut.uio_in.value = 0b00000000   # load_high=0

  # ── Load high byte ────────────────────────────────────────────────
  await RisingEdge(dut.clk)
  dut.ui_in.value  = (n >> 8) & 0xFF
  dut.uio_in.value = 0b00000001   # load_high=1

  # ── Pulse start ───────────────────────────────────────────────────
  await RisingEdge(dut.clk)
  dut.uio_in.value = 0b00000010   # start=1

  await RisingEdge(dut.clk)
  dut.uio_in.value = 0b00000000   # start=0

  # ── Wait for done (uio_out bit 2) ─────────────────────────────────
  for _ in range(10000):
    await RisingEdge(dut.clk)
    if(int(dut.uio_out.value) >> 2) & 1: break
  else: raise cocotb.result.TestFailure(f"TIMEOUT: n={n} never finished")

  result = int(dut.uo_out.value)
  overflow = (int(dut.uio_out.value) >> 3) & 1

  assert result == expected, (
    f"n={n}: got {result} steps, expected {expected}"
  )

  dut._log.info(f"n={n:5d}  steps={result:3d}  overflow={overflow}  ✅")

  await ClockCycles(dut.clk, 5)


@cocotb.test()
async def test_collatz(dut):
  """Run all known Collatz stopping-time test cases."""

  # Start 10 MHz clock (100 ns period)
  cocotb.start_soon(Clock(dut.clk, 100, units="ns").start())

  # ── Reset ─────────────────────────────────────────────────────────
  dut.rst_n.value = 0
  dut.ena.value = 1
  dut.ui_in.value = 0
  dut.uio_in.value = 0
  await ClockCycles(dut.clk, 5)
  dut.rst_n.value = 1
  await ClockCycles(dut.clk, 3)

  # ── Test cases (n, expected_accelerated_steps) ────────────────────
  # Expected values verified against Python reference:
  #   def collatz(n):
  #     s=0
  #     while n!=1:
  #       if n%2==0: k=0;t=n
  #         while t%2==0: t//=2;k+=1
  #         n=t;s+=k
  #       else: n=(3*n+1)//2;s+=2
  #     return s
  test_cases = [
  # (n, steps)
    (1, 0),
    (2, 1),
    (3, 7),
    (6, 8),
    (7, 16),
    (27, 111),
    (871, 178),
  ]

  for n, expected in test_cases: await load_and_run(dut, n, expected)

  dut._log.info("All tests passed!")
