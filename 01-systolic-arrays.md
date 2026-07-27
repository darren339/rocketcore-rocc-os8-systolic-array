# Verification Methodology

OS8 was verified in layers.

```text
individual RTL modules
        ↓
integrated accelerator datapath/control
        ↓
RocketCore + RoCC + OS8 system
        ↓
software reference comparison
```

This approach makes it easier to locate functional problems before they become system-level failures.

## Module-Level Verification

The main SystemVerilog blocks were verified using dedicated testbenches and waveform inspection.

The verified modules include:

- `os8_pe`
- `os8_activation_unit`
- `os8_final_cpa`
- `os8_delay_mem`
- `os8_pe_mesh`
- `os8_sa`
- `os8_rocc_cmd_regs`
- `os8_controller`

The top-level wrapper is primarily an integration boundary, so its most meaningful verification occurs through end-to-end system execution.

## `os8_pe`

Tests cover:

- clear/reset behaviour
- positive signed multiplication
- negative signed multiplication
- carry-save propagation

Representative expected accumulated values include:

```text
3 × 4   → 12
-2 × 5  → -10
77 + 3 propagation pair → 80
```

## `os8_activation_unit`

Tests cover:

- no shift
- arithmetic right shift
- negative signed shift
- ReLU clipping

Examples:

```text
64 >> 0 = 64
64 >> 2 = 16
-32 >>> 1 = -16
ReLU(-16) = 0
```

## `os8_final_cpa`

Tests confirm that sum and carry are converted into a conventional signed result.

They include ordinary positive values and two's-complement edge behaviour.

## `os8_delay_mem`

Tests verify the staggered stream.

After loading, the first lane is visible earlier than later lanes. Successive enable cycles expose the delayed values progressively.

This confirms the timing skew required to create the systolic wavefront.

## `os8_pe_mesh`

The mesh test checks the distributed PE structure using a reduced configuration where the carry-save output can be inspected directly.

It verifies:

- clearing
- positive arithmetic
- signed arithmetic
- propagation behaviour

## `os8_sa`

The compute-core test performs complete matrix multiplication using small test matrices.

Cases include:

- identity multiplication
- positive matrix multiplication
- signed matrix multiplication
- zero matrix

This validates the interaction of delay memories, PE mesh, propagation, and final CPA.

## `os8_rocc_cmd_regs`

Tests verify:

- A pointer command
- B pointer command
- activation configuration
- execution command decoding
- `start_pulse`
- operating-mode selection
- response-register capture

## `os8_controller`

The controller test exercises:

- reset/idle
- A memory loading
- B memory loading
- signed byte interpretation
- C output stores

The memory interface is modelled by the testbench so that request and response behaviour can be inspected directly.

## Waveform Observation Signals

Some testbenches use scalar `observe_*` signals that mirror unpacked array ports.

These signals exist only to make waveforms easier to inspect and do not alter the RTL design.

## System-Level Verification

The integrated design is tested in Chipyard using Verilator.

`os8_test.c` runs as a bare-metal program on the simulated RocketCore.

For each workload:

1. software creates the matrix data
2. normal C code computes a reference result
3. RoCC instructions invoke OS8
4. OS8 writes the hardware result to memory
5. software compares both outputs element by element

All three 1×1-to-32×32 benchmark sweeps passed 32 out of 32 correctness tests.

## CNN-Style Test Cases

The software test program also includes 8×8 workload patterns using:

- random signed INT8 data
- 4-bit-style values
- sparse matrices
- identity matrices
- external weights
- ReLU
- arithmetic right shift

These tests exercise the design beyond simple dense positive matrix multiplication.

## Related Files

- `verification/testbenches/`
- `software/os8_test.c`
- `software/external_weights.h`
