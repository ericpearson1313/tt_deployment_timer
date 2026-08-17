# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Set the input values you want to test
    dut.ui_in.value = 20
    dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 1)

    # match the actual expected output of your module:
    assert dut.cont_enable.value == 1
    assert dut.speaker.value == 0
    assert dut.deploy.value == 0
    assert dut.dump.value == 1
    assert dut.charge.value == 0
    assert dut.status_led.value == 1
    assert dut.sda_accel_oe.value == 0
    assert dut.sda_accel_out.value == 0
    assert dut.scl_accel_oe.value == 0
    assert dut.scl_accel_out.value == 0


    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
