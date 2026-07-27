# RocketCore Integration, Operation and Verification

## 1. RocketCore and RoCC

The OS8 accelerator is integrated with RocketCore through the **Rocket Custom Coprocessor (RoCC)** interface.

RoCC allows custom RISC-V instructions to invoke a tightly coupled hardware accelerator while RocketCore remains responsible for normal program execution and workload management.

The command path is:

```text
C program
    ↓
custom RISC-V instruction
    ↓
RocketCore decode
    ↓
RoCC command channel
    ↓
OS8 command registers
    ↓
OS8 controller
    ↓
systolic datapath
```

![RocketCore custom-instruction command path to the OS8 accelerator](../assets/image-13.png)

### Command Fields

The accelerator uses the RISC-V `custom0` opcode space.

The relevant instruction fields are:

- `funct7` — selects the accelerator command,
- `rs1` — carries a pointer or configuration value,
- `rd` — identifies the destination register when a response is required,
- `rs2` — unused,
- `funct3` — fixed to `000`.

At the accelerator interface:

```text
funct7 → cmd_funct
rs1    → cmd_rs1
rd     → cmd_rd
```

A command is accepted when:

```text
cmd_valid && cmd_ready
```

are asserted during the same cycle.

This valid-ready handshake ensures that RocketCore only transfers a command when the accelerator is able to accept it.

---

## 2. Custom Instruction Map

The OS8 accelerator uses the RISC-V `custom0` opcode, encoded as `0001011`, for all accelerator commands.

The `funct7` field distinguishes the individual operations.

| [31:25] funct7 | [24:20] rs2 | [19:15] rs1 | [14:12] funct3 | [11:7] rd | [6:0] opcode | Operation |
|---|---|---|---|---|---|---|
| `0000000` | unused | A buffer address source register | `000` | unused | `0001011` | Provide A tile buffer address |
| `0000001` | unused | B buffer address source register | `000` | unused | `0001011` | Provide B tile buffer address |
| `0000010` | unused | C output tile address source register | `000` | unused | `0001011` | Provide C output tile buffer address |
| `0000011` | unused | unused | `000` | response destination register | `0001011` | Load A, load B, compute, store C |
| `0000111` | unused | activation configuration source register | `000` | unused | `0001011` | Configure activation unit |
| `0001000` | unused | unused | `000` | response destination register | `0001011` | Load A tile only |
| `0001001` | unused | unused | `000` | response destination register | `0001011` | Load B tile only |
| `0001010` | unused | unused | `000` | response destination register | `0001011` | Compute stored A and B tile |
| `0001011` | unused | unused | `000` | response destination register | `0001011` | Store computed C tile only |
| `0001100` | unused | unused | `000` | response destination register | `0001011` | Load A and B tiles only |
| `0001101` | unused | unused | `000` | response destination register | `0001011` | Compute and store C tile only |

The separated load, compute and store commands allow previously loaded operand tiles to remain resident inside the accelerator.

This enables explicit operand reuse without changing the underlying output-stationary PE dataflow.

---

## 3. Complete Operation Flow

At the software level, matrix multiplication is divided into operations that can be executed by the fixed 8×8 accelerator.

A complete accelerator operation follows this sequence:

1. Software prepares the input matrices.
2. Larger matrices are divided into 8×8 tiles.
3. Incomplete edge tiles are zero-padded.
4. Software provides the A, B and C buffer addresses.
5. Optional activation configuration is provided.
6. Software issues an execution command.
7. The controller loads the required A and B tile data.
8. `os8_sa` begins systolic-array computation.
9. The 8×8 PE mesh performs the MAC operations.
10. Completed carry-save results propagate toward the final CPA stage.
11. Final C values are captured.
12. Arithmetic right shift and optional ReLU are applied.
13. C results are written to memory.
14. The accelerator returns a RoCC response.
15. Software proceeds to the next tile operation when required.

Conceptually:

```text
Software
   │
   │ A/B/C addresses + configuration
   ▼
RoCC Command
   │
   ▼
Command Registers
   │
   ▼
Controller
   │
   ├── Load A
   ├── Load B
   │
   ▼
Systolic Array
   │
   ├── Compute
   ├── Carry-save propagation
   └── Final CPA
   │
   ▼
Activation / Shift
   │
   ▼
Store C
   │
   ▼
RoCC Response
```

This arrangement keeps the hardware datapath fixed while software manages matrices of different dimensions.

---

## 4. Matrix Tiling and Zero Padding

The physical OS8 array always operates on an 8×8 tile.

For a matrix smaller than 8×8, the valid matrix is placed within a complete tile and the unused entries are set to zero:

```text
valid matrix values + zero padding → 8×8 hardware tile
```

For matrices larger than 8×8, software divides the workload into multiple A and B tiles and invokes the accelerator repeatedly.

For example, a matrix dimension larger than eight may require several tile operations along each dimension.

Incomplete edge tiles are zero-padded before being sent to the accelerator.

This allows the hardware to retain a fixed 8×8 architecture without adding variable-size matrix control logic.

The trade-off is that PEs corresponding to padded positions perform operations on zeros.

This tiling behaviour also contributes to the performance pattern observed across different matrix dimensions, particularly when a matrix size crosses an 8-element tile boundary.

---

## 5. B-Matrix Reuse

The complete accelerator operation can execute:

```text
Load A
Load B
Compute
Store C
```

for every tile.

However, the separate command modes allow these stages to be controlled independently.

If the same B tile is required for several operations, it can remain resident inside the accelerator.

For example:

```text
Load B

Load A1
Compute + Store C1

Load A2
Compute + Store C2

Load A3
Compute + Store C3
```

Instead of:

```text
Load A1
Load B
Compute
Store C1

Load A2
Load B
Compute
Store C2

Load A3
Load B
Compute
Store C3
```

The second and subsequent operations therefore avoid repeatedly loading the same B tile.

This models an inference-style workload in which a set of weights may be reused across multiple input activation tiles.

The optimisation occurs at the **controller and software scheduling level**.

The PE array itself remains output-stationary: partial outputs remain associated with their PEs during computation while A and B values move through the array.

---

## 6. Scala / Chisel Integration

The SystemVerilog accelerator is attached to Rocket Chip through a thin Scala/Chisel integration layer.

The repository places these integration files in the `rocc/` directory.

### `os8_matmul.scala`

Defines the accelerator on the Rocket/RoCC side.

It connects the relevant RoCC interfaces to the SystemVerilog implementation, including:

- command channel,
- response channel,
- memory path,
- busy status.

### `os8_wrapper.scala`

Declares the Chisel `BlackBox` corresponding to the SystemVerilog `os8_wrapper`.

It exposes the RTL accelerator ports to the Chisel/Rocket environment and allows the SystemVerilog implementation to be included in the generated design.

### `Configs.scala`

Defines the RoCC attachment using:

```text
OpcodeSet.custom0
```

and associates the OS8 accelerator with the RocketCore configuration.

### `RocketConfigs.scala`

Defines the RocketCore configuration that includes OS8.

The original project placed these files within the appropriate Chipyard and Rocket Chip source directories.

This repository instead groups the accelerator-related integration files together under `rocc/` so that the complete modification can be inspected without navigating the larger Chipyard source tree.

---

## 7. RTL Verification

Individual OS8 RTL modules were verified using dedicated SystemVerilog testbenches before full RocketCore integration.

The testbench source files are stored in the repository under:

```text
verification/
```

The available testbenches are:

```text
verification/
├── tb_os8_activation_unit.sv
├── tb_os8_controller.sv
├── tb_os8_delay_mem.sv
├── tb_os8_final_cpa.sv
├── tb_os8_pe.sv
├── tb_os8_pe_mesh.sv
├── tb_os8_rocc_cmd_regs.sv
├── tb_os8_sa.sv
└── tb_os8_wrapper.sv
```

Each testbench corresponds to a major RTL block and is used to exercise that module independently.

| Testbench | Module under test |
|---|---|
| `tb_os8_activation_unit.sv` | `os8_activation_unit` |
| `tb_os8_controller.sv` | `os8_controller` |
| `tb_os8_delay_mem.sv` | `os8_delay_mem` |
| `tb_os8_final_cpa.sv` | `os8_final_cpa` |
| `tb_os8_pe.sv` | `os8_pe` |
| `tb_os8_pe_mesh.sv` | `os8_pe_mesh` |
| `tb_os8_rocc_cmd_regs.sv` | `os8_rocc_cmd_regs` |
| `tb_os8_sa.sv` | `os8_sa` |
| `tb_os8_wrapper.sv` | `os8_wrapper` |

This module-level verification allows arithmetic, timing, control and data-movement behaviour to be checked before the accelerator is tested as part of the complete processor system.

The testbenches themselves can be found in the repository's [`verification/`](../verification/) directory.

---

## 8. System-Level Verification

After RTL verification, the complete accelerator is integrated with RocketCore and tested in Chipyard using Verilator.

The software test program is stored under:

```text
software/
```

with `os8_test.c` providing the main accelerator test and benchmark workload.

At system level, the verification path is:

```text
C software
    ↓
RocketCore
    ↓
custom RISC-V instruction
    ↓
RoCC interface
    ↓
OS8 accelerator
    ↓
system memory
    ↓
software result comparison
```

For each test workload, software first generates or prepares the input matrices.

A normal software matrix multiplication is used to generate a reference result.

The same workload is then executed using OS8 through the RoCC custom instructions.

After the accelerator stores its result in memory, the software compares the hardware output with the reference result element by element.

Conceptually:

```text
Input Matrices
      │
      ├──────────────► Software Matrix Multiply ──► Reference C
      │
      └──────────────► OS8 Accelerator ──────────► Hardware C
                                                   │
Reference C ───────────────────────────────────────┤
                                                   ▼
                                                Compare
```

This verifies not only the arithmetic datapath, but the complete integration path including:

- custom instruction execution,
- RoCC command transfer,
- command decoding,
- controller operation,
- memory transactions,
- systolic computation,
- output processing,
- result storage.

---

## 9. Functional and Performance Test Groups

The software test program also performs matrix-size sweeps used for functional verification and performance measurement.

Three primary benchmark configurations are used:

| Test | Matrix sizes | B reuse |
|---|---|---:|
| Type 1A | 1×1 to 32×32 | None |
| Type 1B | 1×1 to 32×32 | 5× |
| Type 1C | 1×1 to 32×32 | 10× |

Each matrix size is checked against the software-generated reference result.

The software also includes 8×8 CNN-style workloads containing cases such as:

- signed INT8 values,
- reduced-range values,
- sparse matrices,
- identity matrices,
- external weight data,
- ReLU output processing,
- arithmetic right shifting.

These tests exercise both the basic matrix-multiplication datapath and accelerator features used in lightweight inference workloads.

---

## 10. Verification Structure

The complete verification flow can therefore be divided into two main levels:

```text
RTL Verification
    │
    │ verification/*.sv
    ▼
Individual accelerator modules
    │
    ▼
System Integration
    │
    │ Chipyard + Verilator
    ▼
RocketCore + RoCC + OS8
    │
    ▼
Software reference comparison
```

The `verification/` directory contains the standalone SystemVerilog testbenches used for RTL validation.

The `software/` directory contains the processor-side software used for full-system functional testing and benchmarking.

Together, these verify the accelerator from individual RTL blocks through to execution from software running on RocketCore.

The measured performance and synthesis characteristics of the validated design are discussed in:

[Performance, Scalability and Synthesis](03-performance-scalability-and-synthesis.md)