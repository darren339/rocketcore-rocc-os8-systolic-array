# Benchmarking

## Measurement Method

The system-level benchmark runs on the simulated RocketCore environment.

The software uses the RISC-V `rdcycle` instruction to measure execution cycles.

Software cycles are measured around the reference C matrix multiplication.

Hardware cycles are measured around the RoCC-based accelerator operation.

The reported speedup is:

\[
Speedup = \frac{Software\ cycles}{Hardware\ cycles}
\]

## Matrix-Size Sweep

The benchmark tests square matrices from 1×1 through 32×32.

The physical accelerator is fixed at 8×8, so software handles matrix dimensions through tiling and zero-padding.

## Aggregate Results

| Test | B reuse | Total software cycles | Total hardware cycles | Overall speedup | Correctness |
|---|---:|---:|---:|---:|---:|
| Type 1A | None | 3,222,602 | 672,021 | 4.79× | 32 / 32 |
| Type 1B | 5× | 16,251,427 | 898,490 | 18.08× | 32 / 32 |
| Type 1C | 10× | 32,522,591 | 1,791,535 | 18.15× | 32 / 32 |

## Why Small Matrices Are Slower

A hardware accelerator has invocation and data-movement overhead.

For a very small matrix, there are few useful MAC operations, so fixed overhead forms a large fraction of total execution time.

The hardware may therefore provide little or no speedup for the smallest workloads.

## Why Speedup Rises Within Each Tile Region

As matrix size grows without requiring another tile boundary, more useful arithmetic work is performed relative to the fixed invocation overhead.

This increases accelerator utilisation and generally improves speedup.

## Why the Graph Has a Sawtooth Shape

The accelerator uses fixed 8×8 processing.

At a matrix size that fits efficiently within a given number of tiles, utilisation is relatively high.

When the matrix crosses the next tile boundary, software must schedule additional 8×8 tile operations even though the newly added tile may initially contain many padded or otherwise underused positions.

Hardware cycles therefore jump, causing a speedup drop.

As the matrix grows further, those additional tiles become more fully utilised and speedup rises again.

This produces the repeated sawtooth pattern.

## Why Multiples of Eight Are Important

At dimensions such as 8, 16, 24, and 32, the matrix aligns naturally with the 8×8 physical tile dimensions.

There is less wasted work from partially occupied edge tiles, so these points tend to exhibit strong utilisation.

## Effect of B Reuse

The B-reuse curves remain significantly above the no-reuse case because repeated loading of the B/weight matrix is avoided.

The 5× and 10× aggregate speedups are very similar:

```text
5× reuse  → 18.08×
10× reuse → 18.15×
```

This indicates that most B-loading cost has already been amortised by 5× reuse. Further reuse cannot remove the other remaining costs.

## Interpretation

The benchmark should not be interpreted as a peak arithmetic-throughput test alone.

It measures the behaviour of the complete RocketCore-to-accelerator path, including configuration, memory traffic, computation, and output handling.

That is why explicit reuse has such a large effect on measured speedup.
