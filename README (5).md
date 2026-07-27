# Results

This directory is intended for concise reproducible result summaries rather than raw tool installations or proprietary technology files.

## Benchmark Results

| Configuration | Software cycles | Hardware cycles | Speedup | Correctness |
|---|---:|---:|---:|---:|
| No explicit B reuse | 3,222,602 | 672,021 | 4.79× | 32 / 32 |
| B reused 5× | 16,251,427 | 898,490 | 18.08× | 32 / 32 |
| B reused 10× | 32,522,591 | 1,791,535 | 18.15× | 32 / 32 |

## Synthesis Results

| Metric | Result |
|---|---:|
| Technology | SAED32nm LVT |
| Target frequency | ~700 MHz |
| Total cell area | 240,619.98 |
| Estimated total area | 281,560.63 |
| Dynamic power | 8.9885 mW |
| Leakage power | 369.2892 mW |
| Total estimated power | ~378.28 mW |
| Slack | 0.00 ns |

## Suggested Subdirectories

```text
results/
├── benchmarks/
│   ├── no_reuse.txt
│   ├── reuse_5x.txt
│   └── reuse_10x.txt
└── synthesis/
    ├── area_summary.md
    ├── timing_summary.md
    └── power_summary.md
```

If raw Design Compiler reports are published, ensure they do not contain restricted library paths or other environment-specific information that should not be made public.
