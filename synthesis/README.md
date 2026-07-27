# Synthesis

The complete OS8 accelerator was synthesized using Synopsys Design Compiler with `os8_wrapper` as the top-level design.

The purpose of this synthesis stage was to estimate the implementation cost and timing characteristics of the complete accelerator after RTL-to-gate mapping. The reported results therefore include the command register block, controller, activation unit, systolic-array core, delay memories, PE mesh, final CPA stage, and wrapper-level integration logic.

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

The resulting synthesis reports therefore represent the complete OS8 accelerator hardware rather than only the 8×8 PE array.

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

The exact constraint scripts are not included in this repository because synthesis setup can vary significantly depending on the technology library, process corner, operating conditions, interface assumptions, and target implementation environment.

## Synthesis Flow

The synthesis flow followed the general sequence below:

```text
Read RTL
    ↓
Analyze SystemVerilog sources
    ↓
Elaborate os8_wrapper
    ↓
Link design hierarchy
    ↓
Check design
    ↓
Apply timing and environment constraints
    ↓
Timing-driven optimization
    ↓
compile_ultra
    ↓
Incremental optimization
    ↓
Generate mapped design
    ↓
Generate area, timing and power reports
```

The synthesis process also generated outputs such as the mapped netlist, Design Compiler database, and SDC representation of the applied constraints.

## Area Results

The synthesized design contains:

| Metric | Result |
|---|---:|
| Total cell count | 62,343 |
| Combinational cells | 44,651 |
| Sequential cells | 16,754 |
| Total cell area | 240,619.98 |
| Total area including estimated net interconnect | 281,560.63 |

The combinational area is slightly larger than the sequential area because the accelerator contains substantial arithmetic and control logic.

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
| Reported timing slack | 0.00 ns |
| Timing status | MET |

The reported critical path was located in the controller memory-address generation path.

The path started from a controller register and ended at a `mem_req_addr_reg` register.

This is an important result because the final timing limit was not located directly inside the systolic-array PE arithmetic path.

Instead, the control and memory-interface logic became the limiting path after synthesis.

The reported:

```text
Data arrival time: 0.72 ns
Data required time: 0.72 ns
Slack: 0.00 ns
```

indicates that the design met the applied timing target, but with essentially no additional timing margin under the selected synthesis configuration.

## Power Results

| Power component | Result |
|---|---:|
| Cell internal power | 7.8790 mW |
| Net switching power | 1.1095 mW |
| Total dynamic power | 8.9885 mW |
| Cell leakage power | 369.2892 mW |
| Total estimated power | approximately 378.28 mW |

The estimated power is dominated by leakage rather than dynamic switching power.

The SAED32nm LVT library uses low-threshold-voltage cells, which generally improve timing performance at the cost of increased leakage current.

This contributes to the relatively large leakage component observed in the synthesis estimate.

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
| Total cell area | 240,619.98 |
| Total area including estimated net interconnect | 281,560.63 |
| Timing slack | 0.00 ns |
| Dynamic power | 8.9885 mW |
| Leakage power | 369.2892 mW |
| Total estimated power | approximately 378.28 mW |

## Interpretation

The synthesis results show that the complete OS8 accelerator can be successfully mapped into a standard-cell implementation using the SAED32nm library.

The design satisfies the approximately 700 MHz timing target under the applied synthesis assumptions.

The result also highlights two important implementation observations:

1. The critical timing path is located in the controller memory-address generation logic rather than the PE MAC datapath.
2. Leakage power dominates the estimated total power due in part to the use of the LVT standard-cell library.

These results suggest that future implementation work should focus not only on the systolic-array datapath, but also on controller timing and technology-library selection.

Potential improvements include:

- optimizing the controller address-generation path
- adding pipeline registers where appropriate
- using mixed-threshold or higher-threshold cells
- applying clock gating
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
- optimization settings
- interface assumptions
- output loading
- input transition assumptions
- clock uncertainty
- physical implementation

For this reason, the repository documents the synthesis environment and final synthesis results, but does not treat the original constraint setup as a universal synthesis configuration.
