# Synthesis

The complete OS8 accelerator was synthesised using Synopsys Design Compiler with `os8_wrapper` as
the top-level design.

The purpose of this synthesis stage was to estimate the implementation cost and timing
characteristics of the complete accelerator after RTL-to-gate mapping. The reported results
therefore include the command register block, controller, activation unit, systolic-array core,
delay memories, PE mesh, final CPA stage, and wrapper-level integration logic.

## Synthesis Setup

### Tool

Synopsys Design Compiler

### Technology Library

SAED32nm LVT standard-cell library

### Top-Level Design

```text
os8_wrapper
```

### RTL Included

The following SystemVerilog modules were included in the synthesis hierarchy:

```text
os8_wrapper.sv
os8_rocc_cmd_regs.sv
os8_controller.sv
os8_activation_unit.sv
os8_sa.sv
os8_delay_mem.sv
os8_pe_mesh.sv
os8_pe.sv
os8_final_cpa.sv
```

The resulting synthesis reports therefore represent the complete OS8 accelerator hardware rather
than only the 8×8 PE array.

## Timing Target

The final synthesis target used in the project was approximately:

```text
Clock period: 1.43 ns
Target frequency: approximately 700 MHz
```

The timing environment also included standard synthesis assumptions such as:

- clock uncertainty
- input delay
- output delay
- input transition
- output load
- maximum fanout
- maximum transition
- reset false-path constraints

One further constraint matters for reading the timing result below: a `set_max_delay` exception
of **0.76 ns** was applied to the controller-to-`mem_req_addr_reg` path. That exception, not the
1.43 ns clock, is what the reported critical path is measured against.

The constraint scripts themselves (`.synopsys_dc.setup`, `run.tcl`, `constraints.tcl`) are
reproduced in full in Appendices A15 to A17 of the project report.

## Synthesis Flow

The synthesis flow followed the general sequence below:

```text
Read RTL
    ↓
Analyse SystemVerilog sources
    ↓
Elaborate os8_wrapper
    ↓
Link design hierarchy
    ↓
Check design
    ↓
Apply timing and environment constraints
    ↓
Timing-driven optimisation
    ↓
compile_ultra -gate_clock -timing_high_effort_script -retime
    ↓
Incremental optimisation
    ↓
Generate mapped design
    ↓
Generate area, timing and power reports
```

Note that clock gating is enabled during compilation through `-gate_clock`, so it is already
part of these results rather than an outstanding optimisation.

The synthesis process also generated outputs such as the mapped netlist, Design Compiler
database, and SDC representation of the applied constraints.

## Area Results

The synthesised design contains:

| Metric | Result |
|---|---:|
| Total cell count | 62,343 |
| Combinational cells | 44,651 |
| Sequential cells | 16,754 |
| Total cell area | 240,619.98 µm² |
| Total area including estimated net interconnect | 281,560.63 µm² |

The combinational and sequential counts do not sum to the reported total: 44,651 + 16,754 =
61,405, leaving 938 cells unaccounted for. The report records no macros or black boxes, and the
remaining 938 cells are consistent with the unmapped logic that Design Compiler flags at the end
of the same report (RPT-7).

The combinational area is slightly larger than the sequential area because the accelerator
contains substantial arithmetic and control logic.

Major contributors include:

- 8×8 PE mesh
- carry-save accumulation logic
- final carry-propagate adders
- delay-memory logic
- controller datapath
- memory address generation
- command decoding
- activation processing

The sequential area is mainly associated with:

- controller registers
- command/configuration registers
- PE state
- carry-save storage
- delay registers
- output registers

## Timing Results

| Metric | Result |
|---|---:|
| Target clock period | 1.43 ns |
| Target operating frequency | approximately 700 MHz |
| Reported path constraint | 0.76 ns `set_max_delay` exception |
| Reported timing slack | 0.00 ns |
| Timing status | MET |

The reported critical path was located in the controller memory-address generation path. It
started from a controller register and ended at a `mem_req_addr_reg` register.

This is an important result because the final timing limit was not located inside the
systolic-array PE arithmetic path. The control and memory-interface logic became the limiting
path after synthesis.

The report shows:

```text
Data arrival time:  0.72 ns
Data required time: 0.72 ns
Slack:              0.00 ns  (MET)
```

**The zero slack does not mean the accelerator has reached its frequency limit.** The required
time on this path is not derived from the 1.43 ns clock. It is built up from the 0.76 ns
`set_max_delay` exception applied to the controller memory-address registers in `run.tcl`, less
0.02 ns of clock uncertainty and 0.02 ns of library setup time. The zero slack therefore records
that this path exactly meets a constraint deliberately imposed on it during synthesis.

Measured against the 1.43 ns clock alone, the same path would finish with roughly 0.67 ns to
spare. Because the exception overrides the clock on this path, the worst clock-constrained path
in the design is not the one shown in this report, and the true margin available at 700 MHz
cannot be read from it. Repeating the analysis with the exception removed would be needed to
establish that margin.

## Power Results

| Power component | Result |
|---|---:|
| Cell internal power | 7.8790 mW |
| Net switching power | 1.1095 mW |
| Total dynamic power | 8.9885 mW |
| Cell leakage power | 369.2892 mW |
| Total estimated power | approximately 378.28 mW |

The estimated power is dominated by leakage rather than dynamic switching power. The SAED32nm
LVT library uses low-threshold-voltage cells, which generally improve timing performance at the
cost of increased leakage current. This contributes to the relatively large leakage component
observed in the synthesis estimate.

## Final Synthesis Summary

| Category | Result |
|---|---:|
| Technology | SAED32nm LVT |
| Synthesis tool | Synopsys Design Compiler |
| Top-level design | `os8_wrapper` |
| Target clock period | 1.43 ns |
| Target operating frequency | approximately 700 MHz |
| Cell count | 62,343 |
| Combinational cells | 44,651 |
| Sequential cells | 16,754 |
| Total cell area | 240,619.98 µm² |
| Total area including estimated net interconnect | 281,560.63 µm² |
| Timing slack on the reported path | 0.00 ns against a 0.76 ns exception |
| Dynamic power | 8.9885 mW |
| Leakage power | 369.2892 mW |
| Total estimated power | approximately 378.28 mW |

## Interpretation

The synthesis results show that the complete OS8 accelerator can be successfully mapped into a
standard-cell implementation using the SAED32nm library, and that it meets the constraints
applied to it.

The result also highlights two implementation observations:

1. The reported critical path is in the controller memory-address generation logic rather than
   the PE MAC datapath — so control and memory-interface timing, not the arithmetic, is what the
   synthesis effort was spent on.
2. Leakage power dominates the estimated total, due in part to the LVT standard-cell library.

These results suggest that future implementation work should focus not only on the systolic-array
datapath, but also on controller timing and technology-library selection.

Potential improvements include:

- re-running timing analysis without the `set_max_delay` exception, to establish the real margin
  at 700 MHz
- optimising the controller address-generation path
- adding pipeline registers where appropriate
- using mixed-threshold or higher-threshold cells to reduce the dominant leakage component
- performing gate-level simulation
- carrying the design into place and route
- evaluating post-layout timing and power

## Important Note

These results are synthesis estimates for the specific configuration used in this project.

They are not:

- fabricated silicon measurements
- FPGA measurements
- post-layout sign-off results
- universally reproducible values for the RTL

Area, timing, and power may vary significantly depending on:

- synthesis constraints
- process corner
- technology library
- threshold-voltage selection
- tool version
- optimisation settings
- interface assumptions
- output loading
- input transition assumptions
- clock uncertainty
- physical implementation
