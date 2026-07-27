# RocketCore and RoCC Integration

## Purpose of RoCC

The Rocket Custom Coprocessor interface allows a RocketCore to invoke a tightly coupled custom accelerator using RISC-V custom instructions.

In this project, RocketCore remains the general-purpose processor and OS8 acts as a matrix-multiplication coprocessor.

```text
C software
   │
   ▼
RISC-V custom0 instruction
   │
   ▼
RocketCore decode
   │
   ▼
RoCC command channel
   │
   ▼
OS8 command registers
   │
   ▼
OS8 controller / datapath
```

## Command Path

The software issues instructions in the `custom0` opcode space.

The important instruction fields are:

- `funct7`: selects the accelerator command
- `rs1`: carries a pointer or configuration value
- `rd`: identifies the destination register for commands that return a response
- `rs2`: unused by this design
- `funct3`: fixed to `000`

After RocketCore recognises the custom instruction, the relevant decoded fields are delivered through the RoCC command interface.

At the SystemVerilog boundary they appear as:

```text
funct7  → cmd_funct
rs1     → cmd_rs1
rd      → cmd_rd
```

A command is accepted when `cmd_valid` and `cmd_ready` are asserted together.

## Response Path

Commands that complete an accelerator operation return a response through the RoCC response channel.

The OS8 controller drives:

- `resp_valid`
- `resp_rd`
- `resp_data`

`resp_ready` comes from the processor side.

The destination register is the `rd` value stored when the execution command is accepted.

## Memory Path

The accelerator loads A/B data and stores C through the RoCC memory interface.

The controller drives request information including:

- request valid
- address
- tag
- command
- access size
- write data

The processor-side memory system returns response-valid, tag, and data signals.

This allows the accelerator to access the same memory hierarchy as the Rocket-based system rather than requiring a separate external memory interface.

## Scala / Chisel Integration

Four Scala-side changes are involved in the project.

### `os8_matmul.scala`

Defines the RoCC accelerator module at the Rocket tile level.

It connects Rocket-side RoCC command, response, memory, and busy signals to the SystemVerilog blackbox.

### `os8_wrapper.scala`

Declares the Chisel `BlackBox` interface corresponding to `os8_wrapper.sv`.

It also references the SystemVerilog source files so that they are included during elaboration and simulation.

### `Configs.scala`

Defines the RoCC attachment mixin through `BuildRoCC` and attaches OS8 using `OpcodeSet.custom0`.

### `RocketConfigs.scala`

Defines the final Chipyard configuration used to build the RocketCore system containing OS8.

## Original Chipyard Locations

The project was integrated using the following locations:

```text
~/chipyard/generators/rocket-chip/src/main/scala/tile/
    os8_matmul.scala
    os8_wrapper.scala

~/chipyard/generators/rocket-chip/src/main/scala/subsystem/
    Configs.scala

~/chipyard/generators/chipyard/src/main/scala/config/
    RocketConfigs.scala

~/chipyard/generators/rocket-chip/src/main/resources/vsrc/
    os8_*.sv

~/chipyard/tests/
    os8_test.c
```

The GitHub repository groups them by purpose instead of reproducing the entire Chipyard tree.

## Why the Accelerator Is a BlackBox

Rocket Chip and Chipyard are primarily constructed in Scala/Chisel. The accelerator RTL was deliberately implemented in SystemVerilog to retain direct control over the datapath and make synthesis and module-level verification straightforward.

The Scala layer therefore acts mainly as the integration bridge, while the actual accelerator architecture remains visible in SystemVerilog.

## Next

See [Custom Instructions](06-custom-instructions.md).
