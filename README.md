# OS8 — An 8×8 Output-Stationary Systolic Array Accelerator for RISC-V RocketCore

OS8 is a fixed 8×8 signed-INT8 matrix-multiplication accelerator with 32-bit accumulation,
attached to a RISC-V RocketCore as a RoCC coprocessor in Chipyard. It uses an
output-stationary systolic dataflow and a carry-save/CPA-factored processing element, supports
operand reuse and ReLU, and has been verified at both RTL and full-system level and synthesised
with Synopsys Design Compiler on the SAED32nm LVT library.

This repository contains the complete RTL, the Scala/Chisel integration layer, the bare-metal
test software, the standalone testbenches and the long-form technical documentation for the
design. It was developed as a final-year undergraduate project at Universiti Putra Malaysia.

## Results at a glance

| | |
|---|---|
| Array | 8×8 output-stationary, 64 PEs |
| Operands | signed INT8 in, 32-bit accumulation |
| Host | RISC-V RocketCore via RoCC (`custom0`) |
| Speedup, no operand reuse | 4.79× over software, 32/32 cases correct |
| Speedup, B tile reused 10× | 18.15× over software, 32/32 cases correct |
| Technology | SAED32nm LVT, Synopsys Design Compiler |
| Target | 1.43 ns period, approximately 700 MHz |
| Cell area | 240,619.98 µm² (281,560.63 µm² including estimated interconnect) |
| Total estimated power | approximately 378.28 mW, leakage-dominated |

Full numbers, and the caveats that go with them, are in
[`docs/03-performance-scalability-and-synthesis.md`](docs/03-performance-scalability-and-synthesis.md)
and [`synthesis/`](synthesis/).

## Repository layout

```text
rtl/            SystemVerilog implementation of the accelerator (9 modules)
rocc/           Scala/Chisel layer attaching OS8 to RocketCore through RoCC
software/       Bare-metal C test program and benchmark workloads
verification/   Standalone SystemVerilog testbenches, one per module
synthesis/      Synthesis setup, flow and results
docs/           Long-form technical documentation
results/        Benchmark and synthesis result summaries
references/     Related work and tools
assets/         Figures used by the documentation
```

## Documentation

The documentation is written to be read without prior knowledge of the project, in three parts:

1. [Background and Architecture](docs/01-background-and-architecture.md) — why systolic arrays
   suit this workload, how output-stationary dataflow works, and how the OS8 hardware is built.
2. [RocketCore Integration, Operation and Verification](docs/02-integration-operation-and-verification.md)
   — how RocketCore drives OS8 over RoCC, the custom instruction set, tiling and operand reuse,
   and how the design was verified.
3. [Performance, Scalability and Synthesis](docs/03-performance-scalability-and-synthesis.md) —
   benchmark results, why the speedup curve behaves as it does, throughput and scaling analysis,
   and the synthesis results.

## Getting started

OS8 is not a standalone project: its files are placed into an existing
[Chipyard](https://github.com/ucb-bar/chipyard) checkout, which supplies Rocket Chip, the
RISC-V toolchain and Verilator.

### 1. Install Chipyard

This project was built and tested against **Chipyard 1.11.0**. Everything below assumes Chipyard
is installed at `~/chipyard`.

```bash
git clone https://github.com/ucb-bar/chipyard.git ~/chipyard
cd ~/chipyard
git checkout 1.11.0
```

Complete the toolchain setup as described in the
[Chipyard setup guide](https://chipyard.readthedocs.io/), and confirm the default Rocket
configuration builds and runs before adding OS8.

> **On other Chipyard versions.** The Scala integration targets the Rocket Chip `BuildRoCC`
> interface as it stands in 1.11.0, and that interface has changed between releases. On a
> different version, `Configs.scala` and `os8_matmul.scala` may need adjusting to match its
> `BuildRoCC` signature and `LazyRoCC` constructor.

### 2. Copy the OS8 files into Chipyard

| From this repository | To |
|---|---|
| `rtl/*.sv` | `~/chipyard/generators/rocket-chip/src/main/resources/vsrc/` |
| `rocc/os8_matmul.scala` | `~/chipyard/generators/rocket-chip/src/main/scala/tile/` |
| `rocc/os8_wrapper.scala` | `~/chipyard/generators/rocket-chip/src/main/scala/tile/` |
| `rocc/Configs.scala` | `~/chipyard/generators/rocket-chip/src/main/scala/subsystem/` |
| `rocc/RocketConfigs.scala` | `~/chipyard/generators/chipyard/src/main/scala/config/` |
| `software/os8_test.c` | `~/chipyard/tests/` |
| `software/external_weights.h` | `~/chipyard/tests/` |

`Configs.scala` and `RocketConfigs.scala` are fragments rather than whole files: their contents
are appended to the existing files of those names, since both already exist in Chipyard.
`Configs.scala` defines the `WithOS8RoCC` mixin, and `RocketConfigs.scala` defines the
`OS8RocketConfig` configuration that uses it.

### 3. Build and run the simulation

Build the simulator for the OS8 configuration:

```bash
cd ~/chipyard/sims/verilator
make CONFIG=OS8RocketConfig
```

Build the bare-metal test binary:

```bash
cd ~/chipyard/tests
make
```

Run the binary on the generated simulator:

```bash
cd ~/chipyard/sims/verilator
make CONFIG=OS8RocketConfig run-binary BINARY=../../tests/os8_test.riscv
```

`os8_test.c` prints the correctness result and the software-versus-hardware cycle counts for
every workload.

### 4. Run a standalone testbench

The testbenches in [`verification/`](verification/) need no processor and no Chipyard. Each one
drives a single module directly. See [`verification/README.md`](verification/README.md) for what
each covers and how to run them.

## Custom instructions

OS8 occupies the RISC-V `custom0` opcode space (`0001011`) and selects operations with `funct7`.
Load, compute and store can be issued separately, which is what makes operand reuse possible —
a B tile can stay resident across many multiplications. The full instruction map is in
[`docs/02-integration-operation-and-verification.md`](docs/02-integration-operation-and-verification.md).

## Status and scope

This is a completed undergraduate project, not an actively maintained library. The design is
deliberately small and fixed at 8×8 so that the entire RTL and integration path stays readable,
rather than competing with generator-based accelerators such as
[Gemmini](https://github.com/ucb-bar/gemmini). Reported area, timing and power are synthesis
estimates for one specific setup — they are not post-layout or silicon results.

## Licence

MIT. See [LICENSE](LICENSE).

## Citation

> D. Chin Jian Hao, *OS8: Design and Validation of a RISC-V RocketCore MAC Operation
> Accelerator*, Faculty of Engineering, Universiti Putra Malaysia, 2026.
> https://github.com/darren339/rocketcore-rocc-os8-systolic-array
