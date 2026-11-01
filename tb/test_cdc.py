# test_cdc.py : cocotb tests for the CDC library (TOPLEVEL = pulse_sync, handshake_sync or bus_sync_bug)
#   two free-running clocks with random periods (not multiples of each other) and a random phase
#   pulse_sync     : every source pulse arrives exactly once, as a 1-cycle pulse
#   handshake_sync : the destination receives exactly the words sent, in order, none lost or repeated
#   bus_sync_bug   : words sent slowly through per-bit synchronizers; RTL simulation has no metastability,
#                    so every word arrives intact and this test PASSES although the design is wrong (formal fails it)
import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

N = 300


async def setup(dut):
    sper, dper = random.randrange(3000, 20000, 2), random.randrange(3000, 20000, 2)
    cocotb.start_soon(Clock(dut.sclk, sper, unit="ps").start())
    await Timer(random.randint(0, dper), unit="ps")
    cocotb.start_soon(Clock(dut.dclk, dper, unit="ps").start())
    dut.srst_n.value = 0; dut.drst_n.value = 0
    for sig in ("spulse", "send", "sdata"):
        if hasattr(dut, sig):
            getattr(dut, sig).value = 0
    await Timer(5 * max(sper, dper), unit="ps")
    dut.srst_n.value = 1; dut.drst_n.value = 1
    dut._log.info("sclk %d ps, dclk %d ps", sper, dper)
    return sper, dper


async def receiver(dut, sig, data, out):
    while True:
        await RisingEdge(dut.dclk)
        if sig.value == 1:
            out.append(int(data.value) if data is not None else 1)


@cocotb.test(timeout_time=50, timeout_unit="ms")
async def test_cdc(dut):
    name = dut._name
    await setup(dut)
    got = []
    if name == "pulse_sync":
        widths = []
        async def width_check():                 # a destination pulse lasts exactly one cycle
            run = 0
            while True:
                await RisingEdge(dut.dclk)
                if dut.dpulse.value == 1:
                    run += 1
                elif run:
                    widths.append(run); run = 0
        cocotb.start_soon(width_check())
        cocotb.start_soon(receiver(dut, dut.dpulse, None, got))
        for k in range(N):
            await FallingEdge(dut.sclk)
            dut.spulse.value = 1
            await FallingEdge(dut.sclk)
            dut.spulse.value = 0
            while len(got) < k + 1:              # usage rule: next pulse after the previous one arrived
                await RisingEdge(dut.sclk)
            for _ in range(random.randint(0, 3)):
                await RisingEdge(dut.sclk)
        assert len(got) == N, f"{len(got)} pulses received, {N} sent"
        assert all(w == 1 for w in widths), f"destination pulse widths {set(widths)}"
    else:
        sent = []
        cocotb.start_soon(receiver(dut, dut.dvalid, dut.ddata, got))
        while len(sent) < N:
            await FallingEdge(dut.sclk)
            want = random.random() < 0.7
            w = random.getrandbits(len(dut.sdata))
            if name == "bus_sync_bug":           # no ready: send slowly, and only words that really change
                while w == (sent[-1] if sent else 0):
                    w = random.getrandbits(len(dut.sdata))
                dut.send.value = 1; dut.sdata.value = w
                await FallingEdge(dut.sclk)
                dut.send.value = 0
                sent.append(w)
                for _ in range(8):
                    await RisingEdge(dut.dclk)
                continue
            dut.send.value = int(want); dut.sdata.value = w
            await RisingEdge(dut.sclk)
            if want and dut.sready.value == 1:
                sent.append(w)
        await FallingEdge(dut.sclk)
        dut.send.value = 0
        for _ in range(20):
            await RisingEdge(dut.dclk)
        assert got == sent, f"received {len(got)} words, sent {len(sent)}; first difference at " \
            f"{next((i for i, (a, b) in enumerate(zip(got, sent)) if a != b), min(len(got), len(sent)))}"
    dut._log.info("%s: %d transfers, all correct", name, N)
