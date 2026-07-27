# Output-Stationary Dataflow

OS8 uses output-stationary, or OS, dataflow.

## Meaning of "Output Stationary"

For

\[
C_{ij}=\sum_k A_{ik}B_{kj}
\]

the PE associated with output `C[i][j]` accumulates its partial result locally. A and B operands stream through the array while the partial sum remains resident.

Conceptually:

```text
A ─────►
        ┌───────────────┐
B  │    │      PE       │
   ▼    │               │
        │ P = P + A × B │
        └───────────────┘
              P stays local
```

This avoids repeatedly moving partial sums from PE to PE during the compute phase.

## Data Movement in OS8

In the 8×8 PE mesh:

- A values enter from the left edge.
- A values propagate horizontally across each row.
- B values enter from the top edge.
- B values propagate vertically down each column.
- The partial result associated with an output location is accumulated in carry-save form inside the corresponding PE during computation.

The incoming streams must be time-aligned. If every row and column were injected simultaneously without skew, the wrong A and B elements would meet at many PEs.

OS8 therefore uses two `os8_delay_mem` blocks to form staggered wavefronts.

```text
A row 0:  A00 A01 A02 A03 ...
A row 1:      A10 A11 A12 ...
A row 2:          A20 A21 ...
A row 3:              A30 ...

B column streams are skewed in the corresponding direction.
```

As the wavefront advances, the correct operands meet in each PE on the correct cycles.

## Why B Is Transposed Internally

The compute core receives matrices A and B in conventional matrix form. Before generating the top-edge B stream, `os8_sa` creates a transposed representation `B_T`.

This makes each B column available as one delay-memory lane so that values enter the mesh from the top in the ordering needed for row-by-column matrix multiplication.

## Output Phase

OS8 differs from the simplest textbook OS array because the PE arithmetic is kept in carry-save form. At the end of compute, results are propagated downward through the mesh as sum/carry pairs.

At the bottom of each column, `os8_final_cpa` converts:

```text
carry-save sum
      +
carry-save carry
      ↓
normal 32-bit result
```

The final results are then stored in matrix C.

## OS Compared with WS and IS

| Dataflow | Stationary value | Main reuse benefit | Main movement cost |
|---|---|---|---|
| Output stationary | Partial sum | Avoids repeated partial-sum movement during compute | A and B are streamed |
| Weight stationary | Weight | Efficient repeated weight reuse | Partial sums move |
| Input stationary | Input activation | Efficient repeated activation reuse | Partial sums move |

OS was selected for this project because it gives a clear fixed compute path and keeps accumulation local during the main MAC phase.

The system still supports **B-matrix reuse at the controller/software level**, even though the PE dataflow itself remains output stationary. These are different concepts: OS describes the PE-level dataflow, while B reuse describes avoiding repeated memory loading across accelerator invocations.

## Next

See [OS8 Architecture](03-os8-architecture.md).
