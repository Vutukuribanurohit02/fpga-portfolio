# Project 01 — UART / APB Peripheral

**One line:** a configurable UART transmitter/receiver behind an AMBA APB register interface, simulated, synthesized, and running on a Nexys A7.

---

## What it is

A serial peripheral that an SoC bus master could actually integrate. Not a bare UART — a UART wrapped in a documented register map, which is the difference between a component and a peripheral.

### Register map (APB slave)

| Address | Register | Access | Function |
|---|---|---|---|
| `0x00` | TXDATA | W | Write triggers transmission of the byte |
| `0x04` | RXDATA | R | Last byte received |
| `0x08` | STATUS | R | bit 0 = `tx_busy`, bit 1 = `rx_valid` |
| `0x0C` | BAUDDIV | R/W | Baud rate divider |

### Module breakdown

- `uart_apb.sv` — APB slave: address decode, read/write logic, instantiates everything below
- `baud_gen.sv` — 16× oversampled baud generator (clock divider)
- `uart_tx.sv` — FSM shift register: IDLE → START → DATA → STOP
- `uart_rx.sv` — receive FSM with 2-flop input synchronizer

---

## Design decisions and why

**Why APB rather than a raw interface.** APB is the simplest AMBA bus — no bursts, no pipelining — which makes it the right first bus to implement. The point isn't the protocol's difficulty; it's that a register-mapped peripheral is what an SoC integrator can use, and a bare UART isn't.

**Why 16× oversampling.** The receiver doesn't share a clock with the transmitter. Sampling at 16× the baud rate lets the RX FSM detect the start-bit edge and then sample each subsequent bit near its centre, tolerating clock mismatch between the two ends. Sampling at 1× would require the clocks to agree far more precisely than two independent oscillators do.

**Why a 2-flop synchronizer on RX.** The incoming serial line is genuinely asynchronous to the system clock — it comes from another device. Sampling it directly risks metastability. Two flops in series give the first a full clock period to resolve before the second samples it. This is easy to skip and it bites on real hardware, not in simulation.

---

## Verification

Self-checking SystemVerilog testbenches on both paths, across data patterns chosen to exercise edge bit-values: `0xA5` (alternating), `0x00` (all zeros), `0xFF` (all ones), `0x55` (inverse alternating).

**44/44 TX checks and 4/4 RX checks — 48 total, zero errors.** The asymmetry is worth being able to explain: the TX path is checked bit-by-bit as the frame shifts out, while the RX path is checked once per received byte.

Then synthesized, implemented and programmed onto a **Nexys A7 (Artix-7 XC7A100T)** via a board wrapper — switches drive TXDATA, LEDs reflect STATUS.

**Honest limitation:** this is directed simulation. Four patterns is not the input space. That limitation is exactly what motivates Project 2.

---

## Questions you should be able to answer

1. Why does the RX path need a synchronizer but the TX path doesn't?
2. What breaks if you sample the incoming line at 1× the baud rate instead of 16×?
3. What does `tx_busy` protect against, and what happens if software ignores it?
4. Why is a start bit needed at all, given that the line is idle-high?
5. How would you extend this to support parity, and which module changes?
6. What would you have to add to make this safe with a receive FIFO?

## Where it leads

Project 2 takes the synchronizer idea and builds a full CDC architecture around it — and replaces directed testing with formal proof.
