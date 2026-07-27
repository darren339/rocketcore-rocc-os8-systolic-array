# RTL

This directory contains the SystemVerilog implementation of the OS8 accelerator.

## Hierarchy

```text
os8_wrapper
├── os8_rocc_cmd_regs
├── os8_controller
├── os8_activation_unit
└── os8_sa
    ├── os8_delay_mem ×2
    ├── os8_pe_mesh
    │   └── os8_pe ×64
    └── os8_final_cpa ×8
```

## Files

### `os8_wrapper.sv`

Top-level SystemVerilog accelerator boundary.

Connects RoCC command, response, memory, and busy signals to the internal accelerator modules.

### `os8_rocc_cmd_regs.sv`

Decodes custom commands and stores accelerator configuration.

Maintains A/B/C pointers, response destination, activation configuration, operating mode, and start pulse.

### `os8_controller.sv`

Main control FSM.

Handles memory loading, resident operand buffers, systolic-core start/wait, output selection, activation, stores, responses, and cycle counters.

### `os8_activation_unit.sv`

Combinational arithmetic right-shift and optional ReLU.

### `os8_sa.sv`

Main 8×8 compute core.

Builds skewed input streams, controls the PE mesh, propagates results, applies final CPAs, and produces C.

### `os8_delay_mem.sv`

Generates the staggered A/B wavefront required for systolic timing.

### `os8_pe_mesh.sv`

Instantiates the 8×8 PE array and routes horizontal A, vertical B, and carry-save propagation signals.

### `os8_pe.sv`

Signed INT8 processing element with 32-bit carry-save accumulation and two internal carry-save banks.

### `os8_final_cpa.sv`

Converts the final carry-save sum/carry pair to a normal signed output value.

## Original Chipyard Location

During Chipyard integration these files were placed under:

```text
generators/rocket-chip/src/main/resources/vsrc/
```

See the main documentation for the complete integration path.
