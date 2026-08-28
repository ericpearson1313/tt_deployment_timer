# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 48 MHz
    clock = Clock(dut.clk, 20832, unit="ps")
    cocotb.start_soon(clock.start())

    # test if GL mode (to shorten sim)
    try:
        _ = dut.user_project.i_core.i_accel.byte_limit
        GL_MODE = False
        dut._log.info("RTL Sim")
    except AttributeError:
        GL_MODE = True
        dut._log.info("Gate Sim")

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    #LDT chip inputs
    dut.dip_sw.value = 15; # 4 active low switches
    dut.cont_sense.value = 0; # active high continuity
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    #some data for the first sample
    dut.x.value = 1111;
    dut.y.value = 2222;
    dut.z.value = 3333;

    #If rtl over-ride sample rate to 25x
    if not GL_MODE:
        dut.user_project.i_core.i_accel.byte_limit.value = 28;
        dut._log.info("over-ride and run 400us vs 10ms (25x)")


    dut._log.info("Test project behavior")

    # Set the input values you want to test
    dut.ui_in.value = 20
    dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 1)

    # match the actual expected output of your module:
    assert dut.speaker.value == 0
    assert dut.speaker_n.value == 0
    assert dut.cont_enable.value == 0
    assert dut.deploy.value == 0
    assert dut.dump.value == 1
    assert dut.charge.value == 0
    assert dut.status_led.value == 1

    # Wait for a 350 usec for first sample to run, and check montors
    await ClockCycles(dut.clk, 15*22*120 )
    assert dut.xm.value == 1111
    assert dut.ym.value == 2222
    assert dut.zm.value == 3333

    # wait for these values to be picked up
    dut.x.value = 1234;
    dut.y.value = 2345;
    dut.z.value = 3456;

    # Wait for a 1 tick (it should not update in GL_MODE)
    await ClockCycles(dut.clk, 2*15*11*120 )
    if GL_MODE:
        # old values are still here, gates are real time
        assert dut.xm.value == 1111
        assert dut.ym.value == 2222
        assert dut.zm.value == 3333
        assert dut.cont_enable.value == 0
        assert dut.deploy.value == 0
        assert dut.dump.value == 1
        assert dut.charge.value == 0
        assert dut.status_led.value == 1
        dut._log.info("Short gate sims OK")
        cocotb.pass_test()
    if not GL_MODE:
        # new values , as RTL is 25x real time
        assert dut.xm.value == 1234
        assert dut.ym.value == 2345
        assert dut.zm.value == 3456
        assert dut.user_project.i_core.x.value == 1234
        assert dut.user_project.i_core.y.value == 2345
        assert dut.user_project.i_core.z.value == 3456

    dut._log.info("First Sample OK")
        
    # Otherwise we are runnign in 25x mode and will do a system sim
    # a full deployment sim over the next 100-ish samples (1 sec)



    # start continuity test
    dut._log.info("Continuity Test")
    dut.x.value = 500
    dut.y.value = 0
    dut.z.value = 0
    dut.dip_sw.value = 15
    dut.cont_sense.value = 0
    await ClockCycles(dut.clk, 20*(15*11*120) )

    # start acceleration
    dut._log.info("Acceleration On")
    dut.x.value = 1500
    await ClockCycles(dut.clk, 26*(15*11*120) )
    dut._log.info("Acceleration Off")
    dut.x.value = -500
    await ClockCycles(dut.clk, 24*(15*11*120) )
    dut._log.info("Precharge")
    dut.x.value = 0
    await ClockCycles(dut.clk, 50*(15*11*120) )
    dut._log.info("Deploy")
    await ClockCycles(dut.clk, 25*(15*11*120) )
    dut._log.info("Warble")
    await ClockCycles(dut.clk, 25*(15*11*120) )
    dut._log.info("Warble")
    await ClockCycles(dut.clk, 25*(15*11*120) )
    dut._log.info("Warble")
    await ClockCycles(dut.clk, 25*(15*11*120) )
    dut._log.info("Warble")

    # Last check of outputs
    assert dut.deploy.value == 0
    assert dut.dump.value == 1
    assert dut.charge.value == 0
    assert dut.status_led.value == 1
    # finish up
    await ClockCycles(dut.clk, 48 )
    dut._log.info("Finished Normally")
