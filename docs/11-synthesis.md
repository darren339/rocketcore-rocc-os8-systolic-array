# Synthesis Flow and Results

## Tool and Library

The RTL was synthesised using Synopsys Design Compiler.

The target library is the SAED32nm LVT standard-cell library.

The synthesis top level is:

```text
os8_wrapper
```

Therefore, the reported area, timing, and power cover the complete accelerator wrapper rather than only the PE mesh.

## Included Hardware

The synthesis hierarchy includes:

- RoCC command registers
- controller
- activation unit
- systolic-array core
- delay memories
- 8×8 PE mesh
- final CPA stage
- top-level wrapper logic

## Synthesis Scripts

### `.synopsys_dc.setup`

Defines the Design Compiler search path and target/link libraries.

### `run.tcl`

The main synthesis flow.

It performs operations including:

- WORK library creation
- SystemVerilog analysis
- top-level elaboration
- linking
- design checking
- constraint loading
- timing-driven optimisation
- `compile_ultra`
- incremental optimisation
- output netlist/DDC/SDC generation
- report generation

### `constraints.tcl`

Defines the timing and environmental assumptions used for optimisation.

The target clock is approximately 700 MHz:

```text
period = 1.43 ns
```

The constraints also include assumptions such as:

- clock uncertainty
- input delay
- output delay
- input transition
- output load
- maximum fanout
- maximum transition
- reset false path

## Generated Reports

The flow generates reports including:

```text
area.rpt
area_hier.rpt
timing.rpt
clock.rpt
power.rpt
power_hier.rpt
constraint.rpt
```

## Area Results

| Metric | Result |
|---|---:|
| Cell count | 62,343 |
| Combinational cells | 44,651 |
| Sequential cells | 16,754 |
| Total cell area | 240,619.98 |
| Total area including estimated net interconnect | 281,560.63 |

The design contains substantial combinational logic from arithmetic, memory-address generation, control, and output processing, together with sequential storage in the controller, delay structures, PE state, and command registers.

## Timing Results

| Metric | Result |
|---|---:|
| Target period | 1.43 ns |
| Target frequency | approximately 700 MHz |
| Reported slack | 0.00 ns |
| Timing status | MET |

The critical path is reported in the controller memory-address generation path, ending at a `mem_req_addr_reg` register.

This is significant because the final timing limit is not directly the PE MAC datapath. The system-level control and memory interface can therefore become the dominant timing bottleneck even when the compute datapath is heavily optimised.

A 0.00 ns slack result means the design meets the applied constraint but has essentially no reported timing margin under that synthesis setup.

## Power Results

| Component | Power |
|---|---:|
| Cell internal power | 7.8790 mW |
| Net switching power | 1.1095 mW |
| Total dynamic power | 8.9885 mW |
| Leakage power | 369.2892 mW |
| Total estimated power | approximately 378.28 mW |

Leakage dominates the reported power.

One important reason is the use of the SAED32nm LVT library. Low-threshold-voltage cells are intended to improve speed but generally incur higher leakage.

## Important Limitation

These power values are synthesis estimates.

They should not be interpreted as measured chip power or post-layout sign-off results.

Likewise, the reported area includes Design Compiler's mapped cell area and estimated interconnect contribution, not a completed physical-layout die area.

## Possible Future Improvements

- optimise the controller address-generation critical path
- introduce additional pipelining where appropriate
- use higher-threshold or mixed-threshold cells
- apply clock gating
- perform gate-level simulation
- carry the design into place and route
- evaluate post-layout timing and power
