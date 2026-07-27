# Systolic Arrays

## Why Matrix Multiplication Matters

A large fraction of neural-network computation can be expressed as repeated multiply-and-accumulate operations. In matrix multiplication,

\[
C_{ij} = \sum_k A_{ik} B_{kj}
\]

each output element is a dot product between one row of matrix A and one column of matrix B.

A conventional processor executes these operations through an instruction stream. A systolic array instead maps many of the repeated MAC operations directly onto a regular hardware structure.

## Basic Idea

A systolic array is a grid of processing elements, or PEs. Data is injected at the boundaries of the array and moves between neighbouring PEs in a regular pattern.

For matrix multiplication, one common arrangement is:

```text
              B values
                ↓
          ┌───┬───┬───┬───┐
A values →│PE │PE │PE │PE │
          ├───┼───┼───┼───┤
A values →│PE │PE │PE │PE │
          ├───┼───┼───┼───┤
A values →│PE │PE │PE │PE │
          ├───┼───┼───┼───┤
A values →│PE │PE │PE │PE │
          └───┴───┴───┴───┘
                ↓
```

Each PE receives operands, performs multiplication and accumulation, and forwards data onward.

The value of a systolic array is not only parallel multiplication. Its regular local communication allows the same data item to contribute to several computations as it travels through the array. This reduces the need for every PE to fetch every operand independently from memory.

## Processing Elements

At a conceptual level, a matrix-multiplication PE performs:

\[
P \leftarrow P + A \times B
\]

where `P` is a partial sum.

The exact behaviour depends on the selected dataflow. Different dataflows choose different values to keep stationary inside a PE.

## Common Dataflows

### Output Stationary

The partial sum for an output element remains inside a PE while A and B values move through the array.

### Weight Stationary

A weight remains stored in a PE and is reused across several incoming activations. Partial sums move through the array.

### Input Stationary

An activation remains stored in a PE and is reused across several weights. Partial sums again move between PEs.

There is no universally best dataflow. The most effective choice depends on which data is reused most frequently and on the cost of moving inputs, weights, and partial sums.

OS8 uses **output-stationary dataflow**.

## Why OS8 Uses a Systolic Array

The project targets repeated INT8 matrix multiplication for lightweight AI-style inference workloads. A systolic array is suitable because the workload is regular, MAC-dominated, highly parallel, and naturally tileable.

OS8 uses an 8×8 physical array. A full tile therefore contains:

- 64 PEs
- 64 output elements
- up to 8 products accumulated per output element for one 8×8 multiplication

Larger matrices are handled by software through repeated 8×8 tile operations.

## Next

Continue to [Output-Stationary Dataflow](02-output-stationary.md).
