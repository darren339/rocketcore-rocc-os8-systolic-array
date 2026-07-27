# Memory Behaviour and Data Reuse

## Why Data Movement Matters

The systolic array performs many MAC operations in parallel, but total accelerator execution time also includes moving operands between memory and the accelerator.

For small matrix operations, this fixed overhead can dominate the useful compute work.

OS8 therefore exposes separate load, compute, and store commands so that already loaded operands can be reused.

## Internal Operand Buffers

`os8_controller` stores complete 8×8 A and B tiles internally after loading them from memory.

A compute command operates on these resident tiles.

This means a matrix does not need to be fetched again unless software explicitly loads a replacement tile.

## Baseline Operation

The baseline path repeats both operand loads for each accelerator operation:

```text
A1 load
B1 load
compute
store

A2 load
B2 load
compute
store
```

This is simple, but B memory traffic is repeated even when B has not changed.

## B-Matrix Reuse

A common inference pattern uses one set of weights with several different input activations.

OS8 can model this by loading B once and replacing only A:

```text
B load

A1 load
compute + store

A2 load
compute + store

A3 load
compute + store

...
```

The same B tile remains resident in the controller buffer.

## Benchmark Configurations

The project evaluates three matrix-size sweeps from 1×1 through 32×32.

### Type 1A

No explicit B reuse.

Every matrix multiplication pays the required A and B loading cost.

### Type 1B

Each B matrix is reused across 5 A matrices.

### Type 1C

Each B matrix is reused across 10 A matrices.

## Results

| Configuration | Overall speedup |
|---|---:|
| No explicit B reuse | 4.79× |
| B reused 5× | 18.08× |
| B reused 10× | 18.15× |

The large jump from no reuse to 5× reuse shows that repeated B loading is an important system-level cost.

The difference between 5× and 10× reuse is small because B loading is only one component of hardware time.

Even when B loading is heavily amortised, the accelerator still pays for:

- A loading
- RoCC command handling
- computation
- output processing
- C stores
- tile scheduling overhead

Therefore, increasing reuse eventually reaches diminishing returns.

## PE Dataflow vs System Reuse

B reuse should not be confused with weight-stationary PE dataflow.

OS8 remains an **output-stationary systolic array**.

B reuse occurs at a higher level:

```text
memory / controller buffer level
```

rather than by permanently storing a weight in each PE.

## Relationship to AI Inference

In many inference workloads, model weights remain constant while new activation data arrives repeatedly.

The reuse experiment therefore demonstrates why accelerator performance improves when the workload allows memory traffic to be amortised over multiple compute operations.
