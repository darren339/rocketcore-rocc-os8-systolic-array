# Background and Architecture

## 1. Why Accelerate Matrix Multiplication?

Modern AI workloads contain large numbers of repeated multiply-and-accumulate (MAC) operations. These operations form the main computation in matrix multiplication and fully connected neural-network layers, while convolution operations can also be transformed into matrix-multiplication-style workloads.

For matrix multiplication:

![Matrix multiplication equation](../assets/image.png)

each output element is calculated as the dot product between one row of matrix A and one column of matrix B.

General-purpose processors can execute these operations, but repeated instruction handling, memory access and data movement introduce overhead. A domain-specific accelerator can instead map the regular MAC structure directly into hardware and perform many operations in parallel.

Systolic arrays are particularly suitable for this because they combine:

- regular computation,
- high parallelism,
- local communication between neighbouring processing elements,
- predictable data movement,
- reuse of operands as they move through the array.

---

## 2. Systolic Array Dataflows

A systolic array consists of a regular grid of processing elements (PEs). Each PE performs arithmetic on incoming operands while data moves systematically between neighbouring PEs.

![General systolic array processor structure](../assets/image-6.png)

Different systolic-array dataflows determine which values remain stationary within the array and which values move between PEs.

| Dataflow | Stationary value | Main advantage |
|---|---|---|
| Output stationary | Partial sum / output | Reduces partial-sum movement |
| Weight stationary | Weight | Maximises weight reuse |
| Input stationary | Input activation | Maximises input reuse |

There is no universally optimal dataflow. The appropriate choice depends on the workload and on which data movement is most beneficial to reduce.

---

## 3. Output-Stationary Systolic Array

The accelerator in this project uses an **output-stationary (OS)** dataflow.

Recall that each matrix-multiplication output is calculated as

$$
C_{ij} = \sum_{k=1}^{m} A_{ik}B_{kj}
$$

where $C_{ij}$ is formed by multiplying the corresponding elements of row $i$ of matrix A and column $j$ of matrix B, then accumulating the products over $k$.

In an output-stationary systolic array, each PE is associated with one output element $C_{ij}$. During the main computation, the partial result for that output remains associated with the same PE while A and B operands move through the array.

![Dataflow in a 4×4 output-stationary systolic array](../assets/image-10.png)

The figure illustrates the operation using a 4×4 example.

The **blue A values** enter from the left side of the array and move horizontally across the PE rows. The **red B values** enter from the top and move vertically down the PE columns.

For each PE, the required A and B operands arrive over successive clock cycles. Whenever a matching pair reaches the PE, the two operands are multiplied and the product contributes to the partial sum associated with that output.

For example, the PE responsible for $C_{11}$ computes

$$ 
C_{11}=A_{11}B_{11}+A_{12}B_{21}+A_{13}B_{31}+A_{14}B_{41}
$$

The four products do not arrive simultaneously. Instead, the operand streams are staggered so that the appropriate pair reaches the PE during the same cycle.

Conceptually:

```text
A11 meets B11  → accumulate A11 × B11
A12 meets B21  → accumulate A12 × B21
A13 meets B31  → accumulate A13 × B31
A14 meets B41  → accumulate A14 × B41
```

After the final pair has been processed, the accumulated value represents the completed $C_{11}$ result.

The same computation occurs concurrently across the array. For example:

```text
C12 = A11B12 + A12B22 + A13B32 + A14B42
C21 = A21B11 + A22B21 + A23B31 + A24B41
C44 = A41B14 + A42B24 + A43B34 + A44B44
```

The dashed timing lines in the figure show how different operand streams are injected at different times. This staggering ensures that values corresponding to the same $k$ term meet at the correct PE.

As computation progresses, activity therefore forms a diagonal **systolic wavefront** across the array.

The defining behaviour of output-stationary computation is:

- A values move horizontally,
- B values move vertically,
- each PE is associated with one output $C_{ij}$,
- the partial output remains local during the main MAC phase.

This reduces movement of intermediate output values while allowing A and B operands to be reused as they travel through neighbouring PEs.

OS8 applies this principle to an **8×8 array containing 64 processing elements**.

---

## 4. Overall System Architecture

OS8 is integrated with a RISC-V RocketCore through the **Rocket Custom Coprocessor (RoCC)** interface.

![Overall RocketCore and OS8 accelerator system architecture](../assets/image-11.png)

At a high level, the system consists of:

```text
Software
    │
    ▼
RocketCore
    │
    ▼
RoCC Interface
    │
    ▼
OS8 Accelerator
    │
    ▼
Memory Hierarchy
```

RocketCore continues to execute the main program and manages the overall workload.

Software is responsible for preparing matrices, dividing larger workloads into tiles and issuing the commands required to use the accelerator.

OS8 performs the hardware-accelerated matrix-multiplication operations.

The accelerator accesses matrix data through the processor's memory system, performs the requested computation and writes the resulting output back to memory.

This allows the specialised datapath to operate alongside a general-purpose processor rather than replacing it.

---

## 5. OS8 Accelerator Architecture

The OS8 accelerator can be viewed at a high level as three main functional parts:

```text
             RoCC
              │
              ▼
      ┌─────────────────┐
      │ Command /       │
      │ Control Logic   │
      └────────┬────────┘
               │
               ▼
      ┌─────────────────┐
      │ 8×8 Systolic    │
      │ Compute Array   │
      └────────┬────────┘
               │
               ▼
      ┌─────────────────┐
      │ Output          │
      │ Processing      │
      └────────┬────────┘
               │
               ▼
             Memory
```

![Internal OS8 accelerator architecture](../assets/image-12.png)

### Command and Control

The control portion receives accelerator commands from RocketCore and coordinates the major phases of an operation.

These include:

```text
Load operands
      ↓
Compute
      ↓
Process output
      ↓
Store result
```

The load, compute and store phases can also be controlled separately. This allows previously loaded operand data to be retained and reused across multiple computations.

---

### Systolic Compute Array

The main datapath is an 8×8 output-stationary systolic array.

It operates on signed INT8 matrix operands and accumulates results using a wider 32-bit representation.

Operand streams are staggered before entering the PE array so that the appropriate A and B elements meet at each PE during the correct cycle.

During computation:

```text
A → → → → →
      PE array
B       ↓
↓       ↓
↓       ↓
```

A values propagate horizontally while B values propagate vertically.

The 64 PEs operate concurrently, allowing many MAC operations to take place during each active compute cycle.

---

### Output Processing

After matrix computation is completed, the accelerator converts the accumulated results into conventional output values and optionally performs lightweight post-processing.

The available output operations include:

- arithmetic right shifting,
- ReLU activation.

The processed values are then written back to memory.

This allows basic inference-oriented post-processing to be performed without requiring RocketCore to handle every output element individually.

---

## 6. Systolic Wavefront

A key requirement of the architecture is ensuring that the correct operands arrive at each PE at the same time.

Consider PE $(i,j)$, which must accumulate terms of the form

$$
A_{ik}B_{kj}.
$$

The two operands for a particular value of $k$ must therefore meet at that PE during the same computation cycle.

To achieve this, different rows and columns are given progressively increasing delays before entering the array.

For example, the A streams conceptually behave as:

```text
A row 0:  A00 A01 A02 A03 ...
A row 1:      A10 A11 A12 ...
A row 2:          A20 A21 ...
A row 3:              A30 ...
```

The B streams are staggered correspondingly.

This produces the diagonal systolic wavefront shown earlier.

Once inside the array, A values continue horizontally and B values continue vertically, allowing each operand to contribute to multiple PE computations as it passes through the mesh.

The regular movement of data is one of the main advantages of the systolic-array architecture: communication is primarily local and follows a predictable structure.

---

## 7. Arithmetic Organisation

The OS8 processing elements perform signed INT8 multiplication with 32-bit accumulation.

Rather than repeatedly resolving the entire accumulated result through a conventional wide addition during every MAC operation, the architecture uses a **carry-save representation** during the compute phase.

Conceptually, instead of immediately reducing every operation to:

```text
accumulator = accumulator + product
```

the intermediate result is maintained as two components:

```text
sum
carry
```

These jointly represent the accumulated value.

After computation, the two components are combined to produce the final conventional binary result:

```text
result = sum + carry
```

This organisation keeps the full carry-propagation operation outside the repeated accumulation process.

OS8 also provides separate internal storage for accumulation and result propagation, allowing completed carry-save values to move out of the array after computation.

The detailed RTL implementation of this arithmetic organisation can be found in the [`rtl/`](../rtl/) directory.

---

## 8. Matrix Tiling

The physical accelerator operates on fixed **8×8 matrix tiles**.

A matrix that fits within 8×8 can be mapped directly to one hardware tile.

If its dimensions are smaller than eight, unused entries are filled with zeros.

For example:

```text
Original matrix

a b c
d e f

        ↓ zero padding

8×8 accelerator tile

a b c 0 0 0 0 0
d e f 0 0 0 0 0
0 0 0 0 0 0 0 0
...
```

Larger matrices are divided into multiple 8×8 tiles by software.

Each tile is processed using the same fixed hardware array, and the resulting partial computations are combined as required to construct the complete matrix result.

This approach allows a relatively small accelerator to support matrix dimensions larger than the physical PE array.

It also means hardware utilisation depends on matrix dimensions. Sizes that align well with the 8×8 tile dimensions use more of the available PEs, while incomplete edge tiles contain padded operations.

---

## 9. Data Reuse

The architecture allows operand loading to be separated from computation.

This makes it possible to keep an operand tile inside the accelerator while processing several other tiles.

For example, instead of repeatedly performing:

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

the same B tile can be retained:

```text
Load B once

Load A1
Compute

Load A2
Compute

Load A3
Compute
```

This reduces repeated data transfer when the same operand is needed across multiple matrix operations.

Such behaviour is useful for inference workloads in which the same weight data may be applied to several input activations.

This reuse occurs at the system scheduling and local-buffer level.

The underlying systolic computation remains **output stationary**.

---

## 10. Architectural Summary

OS8 combines a general-purpose RISC-V processor with a specialised matrix-multiplication datapath.

At a high level, the design provides:

- RocketCore integration through RoCC,
- an 8×8 output-stationary systolic array,
- 64 parallel PEs,
- signed INT8 matrix operands,
- 32-bit accumulation,
- staggered systolic data movement,
- carry-save accumulation,
- optional ReLU and output shifting,
- software-managed 8×8 tiling,
- support for operand reuse.

The processor is responsible for flexible workload management, while the accelerator performs the repetitive matrix arithmetic in parallel hardware.

The source RTL implementation is available in:

[`rtl/`](../rtl/)

Processor integration, custom commands, software execution and verification are described in:

[Processor Integration, Operation and Verification](02-integration-operation-and-verification.md)