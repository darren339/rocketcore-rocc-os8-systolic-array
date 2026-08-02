# RocketCore Integration, Operation and Verification

## 1. RocketCore and RoCC

The OS8 accelerator is integrated with RocketCore through the **Rocket Custom Coprocessor (RoCC)** interface.

RoCC allows custom RISC-V instructions to invoke a tightly coupled hardware accelerator while RocketCore remains responsible for normal program execution and workload management.

At a high level, the command path is:

```text
C program
    ↓
custom RISC-V instruction
    ↓
RocketCore
    ↓
RoCC interface
    ↓
OS8 accelerator
```

![RocketCore custom-instruction command path to the OS8 accelerator](../assets/image-13.png)

The accelerator uses the RISC-V `custom0` opcode space.

The main instruction fields used by OS8 are:

- `funct7` — selects the accelerator operation,
- `rs1` — carries an address or configuration value,
- `rd` — identifies a destination register when a response is required,
- `rs2` — unused,
- `funct3` — fixed to `000`.

These custom instructions allow software running on RocketCore to configure the accelerator, provide matrix-buffer addresses and trigger specific execution phases.

---

## 2. Custom Instruction Map

The OS8 accelerator uses the `custom0` opcode, encoded as `0001011`.

Different operations are selected using the `funct7` field.

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

The command set supports both complete operations and separated load, compute and store phases.

This separation is important because previously loaded operand tiles can remain resident and be reused across multiple computations.

---

## 3. Complete Operation Flow

At the software level, matrix multiplication is divided into operations that can be executed by the fixed 8×8 accelerator.

A typical execution sequence is:

1. Software prepares the input matrices.
2. Larger matrices are divided into 8×8 tiles.
3. Incomplete tiles are zero-padded.
4. A, B and C buffer addresses are provided to the accelerator.
5. Optional output-processing configuration is supplied.
6. Software issues an execution command.
7. The required input tiles are loaded.
8. The systolic array performs the matrix multiplication.
9. The computed outputs are converted and optionally post-processed.
10. Results are written back to memory.
11. The accelerator returns completion information.
12. Software continues with the next tile operation if required.

Conceptually:

```text
Software
   │
   ▼
RoCC command
   │
   ▼
Load operands
   │
   ▼
8×8 systolic computation
   │
   ▼
Output processing
   │
   ▼
Store result
   │
   ▼
Return to software
```

This arrangement keeps the accelerator hardware fixed while allowing software to manage matrices of different dimensions and different execution schedules.

---

## 4. Matrix Tiling and Zero Padding

The physical OS8 datapath operates on **8×8 tiles**.

For a matrix smaller than 8×8, the valid values occupy part of the tile and the unused positions are filled with zeros.

```text
valid values + zero padding → complete 8×8 tile
```

For larger matrices, software divides the matrix into multiple 8×8 regions and invokes the accelerator repeatedly.

Incomplete edge tiles are padded with zeros so that the hardware always operates on the same fixed dimensions.

This simplifies the accelerator because it does not require variable-size PE-array control.

The trade-off is that padded locations still consume compute cycles even though the corresponding values are zero.

The tiling behaviour also affects measured performance because matrix dimensions that align with the 8×8 array generally make better use of the available hardware.

---

## 5. Operand Reuse

The accelerator supports separate load and compute operations.

This allows an operand tile to remain resident while other tiles change.

For example, without reuse:

```text
Load A1
Load B
Compute

Load A2
Load B
Compute

Load A3
Load B
Compute
```

With B reuse:

```text
Load B once

Load A1
Compute

Load A2
Compute

Load A3
Compute
```

The repeated B transfers are therefore removed.

This is useful for inference-style workloads in which the same weight tile may be applied to multiple input activation tiles.

This reuse occurs at the software and accelerator-control level.

It does **not** change the underlying systolic dataflow, which remains output stationary.

---

## 6. RocketCore Integration Layer

The SystemVerilog accelerator is connected to RocketCore through a small Scala/Chisel integration layer.

The purpose of this layer is to:

- attach OS8 as a RoCC accelerator,
- expose the SystemVerilog accelerator to the Rocket Chip environment,
- connect the RoCC command and response paths,
- connect accelerator memory access,
- associate OS8 with the `custom0` instruction space,
- include the accelerator in the selected RocketCore configuration.

The integration layer is intentionally thin.

Most accelerator behaviour remains implemented in SystemVerilog, while the Scala/Chisel side provides the required connection between the accelerator and the RocketCore/Chipyard infrastructure.

Conceptually:

```text
RocketCore / Chipyard
        │
        │ RoCC
        ▼
Scala / Chisel integration
        │
        ▼
SystemVerilog OS8 accelerator
```

The associated integration source files are grouped in the repository under:

[`rocc/`](../rocc/)

This keeps the processor-integration code separate from the main accelerator RTL.

---

## 7. Verification Approach

Verification was carried out at two main levels:

```text
RTL-level verification
        ↓
Full-system verification
```

At RTL level, dedicated SystemVerilog testbenches were used to check the accelerator hardware before processor integration.

These testbenches are stored under:

[`verification/`](../verification/)

They cover the major accelerator blocks and allow arithmetic, control and data-movement behaviour to be exercised independently.

The repository contains:

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
└── tb_os8_wrapper_full.sv
```

These are provided as the standalone RTL verification environment for the accelerator.

---

## 8. System-Level Verification

After RTL verification, OS8 is integrated with RocketCore and tested in Chipyard using Verilator.

The full-system test checks the complete path from processor software to hardware execution and back to software.

```text
C software
    ↓
RocketCore
    ↓
RoCC
    ↓
OS8 accelerator
    ↓
memory
    ↓
result comparison
```

For each workload, software generates or prepares the input matrices.

A conventional software matrix multiplication is used to produce a reference result.

The same workload is then executed by OS8.

After the accelerator writes its result to memory, the software compares the hardware result with the software reference.

Conceptually:

```text
Input matrices
      │
      ├──────────────► Software calculation ──► Reference result
      │
      └──────────────► OS8 accelerator ───────► Hardware result
                                                   │
Reference result ──────────────────────────────────┤
                                                   ▼
                                                Compare
```

This verifies the combined behaviour of:

- software invocation,
- RocketCore execution,
- RoCC communication,
- accelerator control,
- memory access,
- systolic computation,
- output storage.

The processor-side test and benchmark software is stored under:

[`software/`](../software/)

---

## 9. Functional and Benchmark Workloads

The software verification includes matrix-size sweeps from 1×1 through 32×32.

Three main benchmark configurations are used:

| Test | Matrix sizes | B reuse |
|---|---|---:|
| Type 1A | 1×1 to 32×32 | None |
| Type 1B | 1×1 to 32×32 | 5× |
| Type 1C | 1×1 to 32×32 | 10× |

The hardware result for each workload is checked against the corresponding software-generated reference result.

Additional 8×8 workloads exercise matrix and output-processing behaviour using cases such as:

- signed INT8 values,
- smaller integer ranges,
- sparse matrices,
- identity matrices,
- external weight data,
- ReLU,
- arithmetic right shifting.

These tests extend verification beyond a single dense positive matrix-multiplication case.

---

## 10. Verification Summary

The project therefore validates OS8 at both hardware and system level.

```text
SystemVerilog testbenches
        ↓
RTL accelerator
        ↓
RocketCore + RoCC integration
        ↓
Chipyard / Verilator execution
        ↓
software reference comparison
```

The RTL testbenches verify the standalone hardware implementation, while the system-level software verifies that the accelerator operates correctly when invoked from RocketCore through RoCC.

The relevant repository directories are:

```text
rocc/          → RocketCore / RoCC integration
verification/  → SystemVerilog testbenches
software/      → full-system tests and benchmarks
```

The measured performance and synthesis characteristics of the verified design are discussed in:

[Performance, Scalability and Synthesis](03-performance-scalability-and-synthesis.md)