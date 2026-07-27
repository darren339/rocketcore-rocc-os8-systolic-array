# Synthesis

This directory contains the Synopsys Design Compiler flow used to synthesise the complete OS8 accelerator.

## Top Level

```text
os8_wrapper
```

The synthesis therefore includes the control/interface logic as well as the 8×8 compute core.

## Files

### `.synopsys_dc.setup.example`

Template for configuring Design Compiler library/search paths.

The original project used the SAED32nm LVT standard-cell library and the DesignWare foundation library.

Do not commit proprietary or institution-specific library files to a public repository.

### `run.tcl`

Main synthesis script.

The documented flow:

1. creates the WORK library
2. analyses the SystemVerilog RTL
3. elaborates `os8_wrapper`
4. links the hierarchy
5. checks the design
6. loads timing constraints
7. performs timing-driven optimisation
8. runs `compile_ultra`
9. performs incremental optimisation
10. writes design outputs
11. generates area, timing, power, clock, hierarchy, and constraint reports

### `constraints.tcl`

Applies the synthesis timing/environment constraints.

The final documented target is approximately 700 MHz, corresponding to a 1.43 ns clock period.

## Reported Results

| Metric | Result |
|---|---:|
| Total cell area | 240,619.98 |
| Total area including estimated interconnect | 281,560.63 |
| Cell count | 62,343 |
| Timing slack | 0.00 ns |
| Dynamic power | 8.9885 mW |
| Leakage power | 369.2892 mW |
| Total estimated power | ~378.28 mW |

See `docs/11-synthesis.md` for interpretation and limitations.
