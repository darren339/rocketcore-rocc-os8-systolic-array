# OS8 Accelerator Architecture

## Overview

OS8 is an 8×8 output-stationary matrix-multiplication accelerator attached to a RISC-V RocketCore through RoCC.

Its architecture separates:

- processor-side configuration,
- memory transfer and sequencing,
- systolic computation,
- output processing.

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

## 1. `os8_wrapper`

`os8_wrapper` is the top-level SystemVerilog boundary of the accelerator.

It connects the externally visible RoCC-style signals to the internal modules:

- command channel
- response channel
- memory request channel
- memory response channel
- busy status

The wrapper itself is mainly integration logic. Command signals are routed to `os8_rocc_cmd_regs`, while memory and response handling are performed by `os8_controller`.

The top-level `busy` output reflects accelerator activity.

## 2. `os8_rocc_cmd_regs`

This block decodes the accelerator command selected by the RoCC `funct7` field.

It stores:

- A buffer pointer
- B buffer pointer
- C buffer pointer
- response destination register
- ReLU enable
- output shift amount
- selected operating mode

When an execution command is accepted, it generates a one-cycle `start_pulse` for the controller.

It refuses new work while the controller is busy.

## 3. `os8_controller`

The controller is the system-level sequencer.

It is responsible for:

- loading A from memory
- loading B from memory
- keeping loaded tiles resident for reuse
- starting the systolic core
- waiting for computation to complete
- selecting output elements
- applying activation/scaling
- packing store data
- writing C back to memory
- generating the RoCC response
- collecting cycle information

The design supports combined and separated operations. This is what makes explicit operand reuse possible.

## 4. `os8_activation_unit`

The activation unit is a small combinational output-processing block.

It performs:

1. arithmetic right shift
2. optional ReLU

For a signed input `x` and shift amount `s`:

```text
shifted = x >>> s
```

If ReLU is enabled and `shifted` is negative, the output becomes zero. Otherwise, `shifted` passes through unchanged.

## 5. `os8_sa`

`os8_sa` is the main compute core.

It receives complete 8×8 matrices A and B from the controller. Internally it:

- transposes B into `B_T`
- loads A and `B_T` into two staggered delay-memory structures
- generates A and B wavefronts
- controls the PE mesh
- manages carry-save buffer selection
- propagates completed results downward
- applies the final CPA stage
- captures the final matrix C
- asserts `done` when computation finishes

## 6. `os8_delay_mem`

Two delay-memory instances generate the skew required by the systolic array.

One processes A. The other processes `B_T`.

Each row/lane receives a different starting delay so that correct operand pairs meet inside the mesh.

## 7. `os8_pe_mesh`

The PE mesh contains 64 `os8_pe` instances.

A propagates horizontally through `a_pipe`.

B propagates vertically through `b_pipe`.

The mesh distributes:

- `en`
- `clear`
- `prop_sel`
- `prop_shift`

During result propagation, sum/carry pairs move downward. The bottom row exposes `bottom_sum` and `bottom_carry`.

## 8. `os8_pe`

Each PE:

- accepts signed INT8 A and B
- multiplies them
- sign-extends the product to the accumulator width
- performs carry-save accumulation
- maintains two carry-save banks
- can propagate one bank vertically while the other bank is used for computation

The PE therefore avoids a full carry-propagate addition on every accumulation cycle.

See [CPA-Factored Processing Element](04-cpa-factored-pe.md).

## 9. `os8_final_cpa`

The final CPA converts the carry-save pair into an ordinary signed 32-bit result:

```text
result_out = sum_in + carry_in
```

One instance is generated per output column.

## Hardware/Software Boundary

The physical datapath always operates on an 8×8 tile.

The processor software is responsible for:

- arbitrary matrix dimensions
- tiling
- zero-padding incomplete tiles
- repeated accelerator calls
- accumulation across K tiles
- selecting when data can be reused

This keeps the accelerator RTL compact while still supporting matrix sizes beyond 8×8.

## Related Source

- `rtl/os8_wrapper.sv`
- `rtl/os8_rocc_cmd_regs.sv`
- `rtl/os8_controller.sv`
- `rtl/os8_activation_unit.sv`
- `rtl/os8_sa.sv`
- `rtl/os8_delay_mem.sv`
- `rtl/os8_pe_mesh.sv`
- `rtl/os8_pe.sv`
- `rtl/os8_final_cpa.sv`
