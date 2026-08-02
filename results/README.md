# Results

Concise result summaries for the OS8 accelerator. Raw tool output, technology files and anything
environment-specific are deliberately kept out of this repository.

## Benchmark Results

Square matrices from 1×1 to 32×32, 32 testcases per configuration. Software cycles come from an
ordinary C matrix multiplication on RocketCore; hardware cycles cover the full RoCC-controlled
accelerator path. Each speedup is the ratio of the summed software cycles to the summed hardware
cycles, so the larger matrices dominate both totals.

| Configuration | Software cycles | Hardware cycles | Speedup | Correctness |
|---|---:|---:|---:|---:|
| No explicit B reuse | 3,222,602 | 672,021 | 4.79× | 32 / 32 |
| B reused 5× | 16,251,427 | 898,490 | 18.08× | 32 / 32 |
| B reused 10× | 32,522,591 | 1,791,535 | 18.15× | 32 / 32 |

The aggregate figures hide a per-size effect worth knowing about: below 4×4 the accelerator is
slower than software (0.06×, 0.20× and 0.53× at 1×1, 2×2 and 3×3), crossing over at 4×4 with
1.08×. Each tile operation costs roughly 840 cycles whether or not the tile is full.

## Synthesis Results

| Metric | Result |
|---|---:|
| Technology | SAED32nm LVT |
| Synthesis tool | Synopsys Design Compiler |
| Target clock period | 1.43 ns |
| Target frequency | approximately 700 MHz |
| Cell count | 62,343 |
| Total cell area | 240,619.98 µm² |
| Total area including estimated interconnect | 281,560.63 µm² |
| Dynamic power | 8.9885 mW |
| Leakage power | 369.2892 mW |
| Total estimated power | approximately 378.28 mW |
| Slack on the reported path | 0.00 ns, against a 0.76 ns `set_max_delay` exception |

The 0.00 ns slack is measured against a `set_max_delay` exception applied to the controller
memory-address path, not against the 1.43 ns clock, so it does not mean the design has reached
its frequency limit. See [`synthesis/README.md`](../synthesis/README.md) for the full reading of
that result.

These are synthesis estimates for one specific setup — not post-layout, FPGA or silicon
measurements.

## Adding raw results

If Design Compiler reports or raw benchmark logs are added here later, check first that they
contain no absolute library paths, licence server names or other environment-specific detail that
should not be public.
