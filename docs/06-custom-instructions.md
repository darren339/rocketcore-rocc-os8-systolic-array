# Custom Instructions

OS8 uses the RISC-V `custom0` opcode space.

The `funct7` field selects the accelerator operation.

## Instruction Fields

```text
31        25 24    20 19    15 14   12 11     7 6      0
+-----------+--------+--------+-------+--------+--------+
|  funct7   |  rs2   |  rs1   |funct3 |   rd   | opcode |
+-----------+--------+--------+-------+--------+--------+
```

For OS8:

- opcode = `custom0`
- funct3 = `000`
- rs2 = unused
- rs1 = pointer or configuration value when required
- rd = response destination for commands that return a value

## Command Map

| funct7 | Operation | Purpose |
|---:|---|---|
| 0 | Set A pointer | Store address of A tile buffer |
| 1 | Set B pointer | Store address of B tile buffer |
| 2 | Set C pointer | Store address of output tile buffer |
| 3 | Full operation | Load A, load B, compute, store C |
| 7 | Activation configuration | Configure ReLU and arithmetic shift |
| 8 | Load A | Load A tile only |
| 9 | Load B | Load B tile only |
| 10 | Compute | Compute using resident A and B tiles |
| 11 | Store C | Store the computed C tile only |
| 12 | Load A + B | Load both operand tiles without computing |
| 13 | Compute + store | Compute resident tiles and store C |

Function codes 4–6 are not used by the documented design.

## Configuration Commands

Pointer commands do not immediately start computation.

For example:

```text
funct7 = 0
rs1    = address of A tile
```

updates the internal A pointer.

Similarly, function codes 1 and 2 update B and C pointers.

## Activation Configuration

Function code 7 uses `rs1` as a packed configuration value.

The implementation stores:

- ReLU enable
- arithmetic right-shift amount

The activation unit applies the shift and optional ReLU during the output-store path.

## Execution Modes

The combined command, function 3, performs:

```text
LOAD A
LOAD B
COMPUTE
STORE C
```

The split commands expose the stages individually.

This is important because the accelerator's internal A and B buffers can remain populated after a load. Software can therefore avoid reloading a matrix that has not changed.

## Example: B Reuse

Instead of repeating:

```text
load A1
load B
compute
store

load A2
load B
compute
store
```

software can perform:

```text
load B

load A1
compute + store

load A2
compute + store

load A3
compute + store
```

This is the mechanism used by the B-reuse benchmarks.

## Handshake

A command is processed only when:

```text
cmd_valid && cmd_ready
```

are true in the same cycle.

The command-register block does not accept a new execution command while the controller FSM is busy.

## Related Source

- `rtl/os8_rocc_cmd_regs.sv`
- `rocc/os8_matmul.scala`
- `software/os8_test.c`
