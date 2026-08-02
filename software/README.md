# Software

This directory contains the bare-metal C-side workload and validation code used with the RocketCore + OS8 system.

## Dependencies

`os8_test.c` includes `rocc.h`, which supplies the `ROCC_INSTRUCTION_*` macros used to emit the
custom0 instructions. That header is not part of this repository — it ships with Chipyard at
`~/chipyard/tests/rocc.h`, which is the same directory `os8_test.c` is copied into, so no extra
setup is needed. `external_weights.h` is provided here and must be copied alongside it.

## `os8_test.c`

The main test program.

It performs several functions:

- prepares input matrices
- computes a software reference matrix multiplication
- builds 8×8 hardware tiles
- zero-pads incomplete tiles
- sends RoCC configuration commands
- invokes the accelerator
- supports separated load/compute/store operations
- exercises B-matrix reuse
- measures cycles using `rdcycle`
- compares hardware and software outputs
- prints correctness and speedup information

## Main Benchmark Groups

### Type 1A

Matrix-size sweep from 1×1 to 32×32 with no explicit B reuse.

### Type 1B

Same sweep with B reused 5 times.

### Type 1C

Same sweep with B reused 10 times.

## CNN-Style Tests

The program also contains fixed 8×8 test cases with patterns including:

- random signed INT8 values
- reduced-range / 4-bit-style values
- sparse weights
- identity matrices
- external weights
- activation enabled/disabled
- output shift

## `external_weights.h`

Contains external weight data used by selected CNN-style validation cases.

## Tiling

The hardware core is fixed at 8×8.

Software therefore handles larger matrices by repeatedly building tile buffers and accumulating tile results into the full C matrix.

For incomplete edge tiles, unused entries are filled with zero.

## Original Chipyard Location

The main test program was placed under:

```text
~/chipyard/tests/
```

and compiled to a RISC-V bare-metal binary before execution in the Chipyard simulator.
