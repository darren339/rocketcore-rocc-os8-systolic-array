# Background and Architecture

## 1. Why Accelerate Matrix Multiplication?

Modern AI workloads are dominated by repeated multiply-and-accumulate operations. These operations appear in matrix multiplication, fully connected layers and convolution layers after the computation is transformed into GEMM-style operations.

For matrix multiplication:

![alt text](image.png)

each output element is a dot product between one row of matrix A and one column of matrix B.

General-purpose processors can execute this computation, but repeated instruction handling, cache behaviour and data movement introduce overhead. A domain-specific accelerator instead maps the repeated MAC structure directly into hardware.

Systolic arrays are well suited to this because they combine:

- regular computation,
- high parallelism,
- local communication between neighbouring processing elements,
- predictable data movement,
- repeated reuse of operands as data moves through the array.

---

## 2. Systolic Array Dataflows


A systolic array consists of a grid of processing elements, or PEs. Each PE performs arithmetic on incoming operands and forwards data to neighbouring PEs.

![alt text](image-6.png)

Different dataflows decide which value is retained inside the PE and which values move.

| Dataflow | Stationary value | Main advantage |
|---|---|---|
| Output stationary | Partial sum | Reduces partial-sum movement |
| Weight stationary | Weight | Maximises weight reuse |
| Input stationary | Input activation | Maximises input reuse |

The best dataflow depends on workload characteristics.

### Output Stationary
## Output-Stationary Systolic Array
## Output-Stationary Systolic Array

The accelerator in this project uses an output-stationary (OS) dataflow.

Recall that matrix multiplication calculates each output element as

$$
C_{ij} = \sum_{k=1}^{m} A_{ik}B_{kj}
$$

This means that each output value $C_{ij}$ is formed by multiplying elements from row $i$ of matrix A with elements from column $j$ of matrix B, then accumulating those products over $k$.

In an output-stationary systolic array, each processing element (PE) is assigned to one output element $C_{ij}$, and that output remains associated with the same PE throughout the compute phase.

![alt text](image-10.png)

The figure illustrates this using a 4×4 example.

The blue A values enter from the left side of the array and move horizontally from one PE to the next. The red B values enter from the top and move vertically down the columns.

For each PE, the corresponding A and B values meet over successive clock cycles.

For example, the PE responsible for $C_{11}$ accumulates

$$
C_{11}=A_{11}B_{11}+A_{12}B_{21}+A_{13}B_{31}+A_{14}B_{41}.
$$

The four products do not arrive at the PE at the same time. Instead, the A and B streams are deliberately staggered so that the correct pair reaches the PE during the same clock cycle.

For $C_{11}$, the sequence is conceptually:

```text
A11 meets B11  → accumulate A11 × B11
A12 meets B21  → accumulate A12 × B21
A13 meets B31  → accumulate A13 × B31
A14 meets B41  → accumulate A14 × B41
```

![alt text](image-9.png)
## 4. Overall System Architecture

The accelerator is attached to a RISC-V RocketCore through the Rocket Custom Coprocessor interface.

The complete system contains:

- RocketCore,
- cache/memory hierarchy,
- RoCC interface,
- accelerator.

[Figure 3.2 from report — Overall system architecture]

RocketCore remains responsible for general program execution and workload orchestration.

OS8 performs the matrix-multiplication kernel.

The accelerator accesses data through the system memory path and returns completion information to the processor through RoCC.

---

## 5. OS8 Hardware Hierarchy

The SystemVerilog accelerator is structured as:

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

[Figure 3.5 from report — Communication between modules in the accelerator]

### `os8_wrapper`

This is the top-level SystemVerilog boundary.

It connects:

- RoCC command signals,
- RoCC response signals,
- memory requests,
- memory responses,
- accelerator busy status.

The wrapper mainly routes signals between the external interface and internal accelerator blocks.

### `os8_rocc_cmd_regs`

This block receives decoded RoCC command fields and stores accelerator configuration.

It maintains:

- A pointer,
- B pointer,
- C pointer,
- response register destination,
- ReLU enable,
- shift amount,
- operating mode.

It also generates the one-cycle start pulse used by the controller.

### `os8_controller`

The controller is the system-level sequencer.

It handles:

- loading A,
- loading B,
- retaining loaded operand tiles,
- starting the compute core,
- waiting for completion,
- selecting C elements,
- applying output processing,
- storing C,
- returning the response,
- collecting cycle information.

The ability to separate load, compute and store phases is what makes explicit operand reuse possible.

### `os8_activation_unit`

The activation block performs:

1. arithmetic right shift,
2. optional ReLU.

Conceptually:

```text
shifted = in_data >>> shift_amount

if ReLU enabled and shifted < 0:
    out_data = 0
else:
    out_data = shifted
```

### `os8_sa`

`os8_sa` is the main compute core.

It:

- receives complete 8×8 A and B tiles,
- transposes B internally,
- feeds A and B through staggered delay memories,
- controls the PE mesh,
- propagates completed carry-save results,
- performs final CPA conversion,
- produces output matrix C,
- asserts done.

---

## 6. Generating the Systolic Wavefront

Correct systolic operation requires the right A and B values to arrive at a PE on the same cycle.

If every matrix row and column were injected simultaneously, many operands would meet at the wrong locations.

OS8 therefore uses two `os8_delay_mem` instances.

One handles A.

One handles the transposed B matrix.

The staggered streams conceptually look like:

```text
A row 0:  A00 A01 A02 A03 ...
A row 1:      A10 A11 A12 ...
A row 2:          A20 A21 ...
A row 3:              A30 ...
```

This creates a diagonal wavefront through the array.

The B stream is skewed in the corresponding direction so that each PE receives the intended `A[i][k]` and `B[k][j]` pair.

---

## 7. Processing Element Architecture

Each PE receives:

- signed INT8 A,
- signed INT8 B,
- control signals,
- carry-save propagation input from the PE above.

The PE:

1. multiplies A and B,
2. sign-extends the product,
3. accumulates using carry-save representation,
4. stores the result in one of two internal carry-save banks.

The PE array therefore does not perform a full carry-propagate addition on every accumulation cycle.

### CPA-Factored Accumulation

A simple MAC would conceptually use:

```text
accumulator = accumulator + A × B
```

which requires carry propagation through a wide adder during repeated accumulation.

OS8 instead keeps the result as:

```text
sum
carry
```

during the compute phase.

A normal binary result is only produced later:

```text
result = sum + carry
```

using the final CPA.

This moves the full carry-propagate operation out of the repeated accumulation path.

### Dual Carry-Save Banks

Each PE has two carry-save banks.

The selected roles are controlled using `prop_sel`.

One bank can be used for computation while the other is used for output propagation.

During the result phase, `prop_shift` causes the selected carry-save result to move downward through the PE column.

At the bottom of the mesh:

```text
bottom_sum
bottom_carry
```

are passed to `os8_final_cpa`.

### Final Carry-Propagate Addition

`os8_final_cpa` performs:

```text
result_out = sum_in + carry_in
```

One CPA is generated for each output column.

The converted results are captured into C.

---

## 8. Architectural Summary

The OS8 datapath therefore combines:

- output-stationary systolic dataflow,
- 64 parallel PEs,
- signed INT8 multiplication,
- 32-bit accumulation,
- carry-save accumulation,
- dual carry-save banks,
- final CPA factoring,
- software-managed 8×8 tiling.

The design intentionally remains compact enough that the complete path from instruction to PE arithmetic can be understood and inspected directly.

For processor integration and execution behaviour, continue to:

[Processor Integration, Operation and Verification](02-integration-operation-and-verification.md)
