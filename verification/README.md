# Verification

The accelerator is verified at both module and system level.

## Module-Level Testbenches

The expected testbench set is:

```text
testbenches/
├── os8_pe_tb.sv
├── os8_activation_unit_tb.sv
├── os8_final_cpa_tb.sv
├── os8_delay_mem_tb.sv
├── os8_pe_mesh_tb.sv
├── os8_sa_tb.sv
├── os8_rocc_cmd_regs_tb.sv
└── os8_controller_tb.sv
```

Each testbench targets the function of one RTL block rather than relying only on end-to-end validation.

## Verification Coverage

- reset / clear behaviour
- signed arithmetic
- carry-save accumulation
- carry-save propagation
- final CPA conversion
- staggered input generation
- PE-mesh data movement
- complete matrix multiplication
- RoCC command decoding
- controller memory reads/writes
- activation and shift processing

## Waveforms

Waveforms are used to confirm both expected values and expected timing relationships.

Some testbenches may expose scalar observation signals such as `observe_A00` to make unpacked array data easier to display. These are testbench-only mirrors and are not part of the synthesised design.

## System-Level Validation

The full accelerator is validated in the Chipyard Verilator environment by executing `os8_test.c` on RocketCore.

The software reference result is compared directly with the hardware result written by OS8.

See `docs/09-verification.md` for the full methodology.
