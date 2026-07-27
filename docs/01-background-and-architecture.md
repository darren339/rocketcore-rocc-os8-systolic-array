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

The accelerator in this project uses an output-stationary (OS) dataflow.

Recall that each element of the matrix product \(C = AB\) is calculated as

$$
C_{ij} = (AB)_{ij} = \sum_{k=1}^{m} A_{ik}B_{kj}
$$

where \(C_{ij}\) is formed by taking row \(i\) of matrix A and column \(j\) of matrix B, multiplying the corresponding elements, and accumulating the products across \(k\).

An output-stationary systolic array maps this computation directly onto a two-dimensional array of processing elements (PEs). Each PE at position \((i,j)\) is responsible for accumulating one output element \(C_{ij}\).

For example, the PE responsible for \(C_{12}\) computes

$$
C_{12}
=
A_{11}B_{12}
+
A_{12}B_{22}
+
A_{13}B_{32}
+\cdots+
A_{1m}B_{m2}.
$$

The PE does not receive all of these operands simultaneously. Instead, the required values arrive over successive clock cycles as the matrices move through the array.

During computation:

- values from matrix A enter from the left side of the array,
- A values propagate horizontally from one PE to the next,
- values from matrix B enter from the top of the array,
- B values propagate vertically down the PE columns,
- whenever \(A_{ik}\) and \(B_{kj}\) meet at PE \((i,j)\), the PE multiplies them,
- the resulting product is accumulated into the partial sum for \(C_{ij}\).

Therefore, over successive values of \(k\), PE \((i,j)\) performs

\[
P_{ij}^{(k)}
=
P_{ij}^{(k-1)}
+
A_{ik}B_{kj},
\]

until every product required by the summation has been included.

The key characteristic of the output-stationary dataflow is that this partial sum remains associated with the same PE throughout the compute phase. The A and B operands move through the array, while the output being accumulated stays stationary.

Conceptually:


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
