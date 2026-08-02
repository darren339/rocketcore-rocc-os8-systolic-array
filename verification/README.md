# Verification

Standalone SystemVerilog testbenches for the OS8 accelerator. These run against the RTL on its
own — no RocketCore, no Chipyard, no software. Each testbench applies a small set of directed
testcases and self-checks the result: each expected value is encoded in the testbench itself, and
each run prints a per-testcase `PASS`/`FAIL` line followed by a final pass/fail tally.

Full-system verification, where the accelerator is driven from C running on RocketCore and the
output is compared against a software reference, is separate and lives in
[`software/`](../software/).

## Testbenches

| Testbench | Module under test | What it exercises |
|---|---|---|
| `tb_os8_pe.sv` | `os8_pe` | Signed INT8 multiply, carry-save accumulation, propagation select and shift |
| `tb_os8_activation_unit.sv` | `os8_activation_unit` | Arithmetic right shift and ReLU, including negative inputs clipped to zero |
| `tb_os8_final_cpa.sv` | `os8_final_cpa` | Final carry-save sum/carry pair resolved to a normal signed value |
| `tb_os8_delay_mem.sv` | `os8_delay_mem` | Generation of the staggered A/B wavefront, one vector per cycle |
| `tb_os8_pe_mesh.sv` | `os8_pe_mesh` | Horizontal A and vertical B routing across the 8×8 mesh, carry-save propagation |
| `tb_os8_sa.sv` | `os8_sa` | The complete compute core: skewed streams in, C matrix out |
| `tb_os8_rocc_cmd_regs.sv` | `os8_rocc_cmd_regs` | Command decode, A/B/C pointer capture, activation configuration |
| `tb_os8_controller.sv` | `os8_controller` | Controller FSM across reset, load and store operations |
| `tb_os8_wrapper_full.sv` | `os8_wrapper` | Full command-to-memory sequence through the assembled accelerator |

`tb_os8_wrapper_full.sv` is the largest and most useful of the set: it drives a complete
configure–load–compute–store sequence and exposes the internal matrix values, so the whole
datapath can be followed in one waveform.

## Running them

Each testbench is self-contained and needs only its module and that module's children from
[`rtl/`](../rtl/). With Verilator:

```bash
verilator --binary --timing -Wno-fatal \
  -I../rtl ../rtl/os8_pe.sv tb_os8_pe.sv --top-module tb_os8_pe
./obj_dir/Vtb_os8_pe
```

Substitute the RTL files the testbench depends on — `tb_os8_sa.sv`, for example, also needs
`os8_pe_mesh.sv`, `os8_pe.sv`, `os8_delay_mem.sv` and `os8_final_cpa.sv`. The wrapper testbench
needs all nine modules. Any SystemVerilog simulator will do; the design uses no vendor-specific
constructs.

The testbenches also dump a VCD, so the internal signal behaviour behind each `PASS` can be
inspected directly in GTKWave or any other waveform viewer.
