# test_fifo.py : cocotb testbench for async_fifo (two unrelated clocks)
#   writer and reader run in their own clock domains with random request rates;
#   scoreboard: every popped word must be the oldest pushed word (order and data);
#   safety: when the FIFO is really full, wfull must be 1 (no overflow); when really empty, rempty must be 1;
#           wafull = 0 must mean more than AF free words, raempty = 0 more than AE words to read;
#   coverage: full / empty reached, requests while full / empty, every occupancy 0..DEPTH, clock ratios
import os
import random
from collections import deque

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

DEPTH = 16
AF = AE = 2                              # almost-full reserve / almost-empty threshold (RTL defaults)
N = int(os.environ.get("N", "2000"))     # words to transfer per test


class Fifo:
    def __init__(self, dut):
        self.dut = dut
        self.q = deque()                 # reference: words written and not yet read
        self.errors = 0
        self.cov = {k: 0 for k in ("wfull seen", "rempty seen after data", "write attempt while full",
                                   "read attempt while empty", "wafull before wfull", "raempty before rempty")}
        self.cov.update({f"occupancy {i}": 0 for i in range(DEPTH + 1)})
        self.written = self.read = 0

    def error(self, msg):
        self.errors += 1
        if self.errors <= 10:
            self.dut._log.error(msg)

    async def start(self, wper, rper):
        d = self.dut
        cocotb.start_soon(Clock(d.wclk, wper, unit="ps").start())
        await Timer(random.randint(0, rper), unit="ps")            # random phase between the clocks
        cocotb.start_soon(Clock(d.rclk, rper, unit="ps").start())
        d.winc.value = 0; d.rinc.value = 0; d.wdata.value = 0
        d.wrst_n.value = 0; d.rrst_n.value = 0
        await Timer(5 * max(wper, rper), unit="ps")
        d.wrst_n.value = 1; d.rrst_n.value = 1
        # the reset synchronizers release each domain 2 of its own clock edges later; wait for both
        for _ in range(4):
            await RisingEdge(d.wclk)
        for _ in range(4):
            await RisingEdge(d.rclk)

    async def writer(self, n, rate):
        d = self.dut
        while self.written < n:
            await FallingEdge(d.wclk)
            want = random.random() < rate
            d.winc.value = int(want)
            d.wdata.value = random.getrandbits(len(d.wdata)) if want else 0
            await RisingEdge(d.wclk)                                 # values before the edge = what the DUT samples
            full = d.wfull.value == 1
            if len(self.q) == DEPTH and not full:
                self.error(f"overflow: FIFO holds {DEPTH} words but wfull = 0")
            if full:
                self.cov["wfull seen"] += 1
            # almost full must be early and safe: wafull = 0 promises more than AF free words
            if d.wafull.value != 1 and DEPTH - len(self.q) <= AF:
                self.error(f"wafull = 0 with only {DEPTH - len(self.q)} free words (AF = {AF})")
            if d.wafull.value == 1 and not full:
                self.cov["wafull before wfull"] += 1
            if want and full:
                self.cov["write attempt while full"] += 1
            if want and not full:
                self.q.append(int(d.wdata.value)); self.written += 1
            self.cov[f"occupancy {len(self.q)}"] += 1
        await FallingEdge(d.wclk)
        d.winc.value = 0

    async def reader(self, n, rate):
        d = self.dut
        while self.read < n:
            await FallingEdge(d.rclk)
            want = random.random() < rate
            d.rinc.value = int(want)
            await RisingEdge(d.rclk)
            empty = d.rempty.value == 1
            if not self.q and not empty:
                self.error("underflow: FIFO is empty but rempty = 0")
            if empty and self.read > 0:
                self.cov["rempty seen after data"] += 1
            # almost empty: raempty = 0 promises more than AE words to read
            if d.raempty.value != 1 and len(self.q) <= AE:
                self.error(f"raempty = 0 with only {len(self.q)} words (AE = {AE})")
            if d.raempty.value == 1 and not empty:
                self.cov["raempty before rempty"] += 1
            if want and empty:
                self.cov["read attempt while empty"] += 1
            if want and not empty:
                got = int(d.rdata.value)
                if not self.q:
                    self.error(f"read {got:#x} from an empty FIFO")
                else:
                    exp = self.q.popleft()
                    if got != exp:
                        self.error(f"read {got:#x}, expected {exp:#x} (word {self.read})")
                self.read += 1
        await FallingEdge(d.rclk)
        d.rinc.value = 0


async def run(dut, wper, rper, wrate, rrate, name):
    f = Fifo(dut)
    await f.start(wper, rper)
    w = cocotb.start_soon(f.writer(N, wrate))
    r = cocotb.start_soon(f.reader(N, rrate))
    await w
    await r
    await RisingEdge(dut.rclk)
    if dut.rempty.value != 1 or f.q:
        f.error(f"FIFO not empty at the end ({len(f.q)} words left)")
    holes = [k for k, v in f.cov.items() if v == 0]
    dut._log.info("%s: wclk %d ps, rclk %d ps, %d words, %d errors, coverage holes: %s",
                  name, wper, rper, f.read, f.errors, holes or "none")
    assert f.errors == 0, f"{f.errors} errors"
    return holes


@cocotb.test(timeout_time=2, timeout_unit="ms")   # a stuck FIFO fails instead of hanging
async def test_fast_writer(dut):
    """Writer clock 2.6x faster: the FIFO fills up, wfull must hold the writer back."""
    holes = await run(dut, 5000, 13000, 0.9, 0.7, "fast writer")
    assert "wfull seen" not in holes
    assert "wafull before wfull" not in holes


@cocotb.test(timeout_time=2, timeout_unit="ms")   # a stuck FIFO fails instead of hanging
async def test_fast_reader(dut):
    """Reader clock 2.6x faster: the FIFO runs empty, rempty must hold the reader back."""
    holes = await run(dut, 13000, 5000, 0.7, 0.9, "fast reader")
    assert "rempty seen after data" not in holes
    assert "raempty before rempty" not in holes


@cocotb.test(timeout_time=2, timeout_unit="ms")   # a stuck FIFO fails instead of hanging
async def test_random_clocks(dut):
    """Random clock periods (3-20 ns, not multiples of each other) and request rates."""
    wper, rper = random.randrange(3000, 20000, 2), random.randrange(3000, 20000, 2)   # ps; cocotb clocks need an even period
    await run(dut, wper, rper, random.uniform(0.3, 1.0), random.uniform(0.3, 1.0), "random clocks")
