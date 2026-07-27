# RocketCore / RoCC Integration

This directory contains the Scala/Chisel-side integration required to attach the SystemVerilog OS8 accelerator to RocketCore.

## Files

### `os8_matmul.scala`

Defines the RoCC accelerator module at the Rocket tile level.

It forwards RoCC command, response, memory, and busy signals between Rocket Chip and the OS8 SystemVerilog blackbox.

Original project location:

```text
generators/rocket-chip/src/main/scala/tile/
```

### `os8_wrapper.scala`

Declares the Chisel `BlackBox` interface for `os8_wrapper.sv`.

It defines the accelerator ports visible to Chisel and includes the RTL resources required for elaboration/simulation.

Original project location:

```text
generators/rocket-chip/src/main/scala/tile/
```

### `Configs.scala`

Contains the RoCC attachment mixin.

The accelerator is attached through the Rocket Chip `BuildRoCC` mechanism using `OpcodeSet.custom0`.

Original project location:

```text
generators/rocket-chip/src/main/scala/subsystem/
```

### `RocketConfigs.scala`

Defines the final Chipyard configuration containing the RocketCore and OS8 accelerator.

Original project location:

```text
generators/chipyard/src/main/scala/config/
```

## Interface Mapping

At a high level:

```text
Rocket RoCC cmd.valid       → cmd_valid
Rocket instruction funct   → cmd_funct
Rocket rs1 data             → cmd_rs1
Rocket rd                   → cmd_rd

OS8 resp_valid              → Rocket RoCC response
OS8 memory requests         → Rocket RoCC memory port
OS8 busy                    → Rocket accelerator busy
```

See `docs/05-rocketcore-rocc.md` and `docs/06-custom-instructions.md` for the architectural explanation.
