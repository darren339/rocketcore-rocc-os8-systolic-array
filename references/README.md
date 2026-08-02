# References and Related Work

This project builds on established work in neural-network accelerator architecture, systolic
arrays, RISC-V, Rocket Chip and RoCC. The major topics and sources are listed below.

## Neural-Network Accelerator Architecture

- V. Sze, Y.-H. Chen, T.-J. Yang and J. S. Emer, "Efficient processing of deep neural networks:
  A tutorial and survey," *Proceedings of the IEEE*, vol. 105, no. 12, pp. 2295–2329, 2017.
  [doi:10.1109/JPROC.2017.2761740](https://doi.org/10.1109/JPROC.2017.2761740)
- W. J. Dally, Y. Turakhia and S. Han, "Domain-specific hardware accelerators,"
  *Communications of the ACM*, vol. 63, no. 7, pp. 48–57, 2020.
  [doi:10.1145/3361682](https://doi.org/10.1145/3361682)
- Y.-H. Chen, T. Krishna, J. S. Emer and V. Sze, "Eyeriss: An energy-efficient reconfigurable
  accelerator for deep convolutional neural networks," *IEEE Journal of Solid-State Circuits*,
  vol. 52, no. 1, pp. 127–138, 2017.
  [doi:10.1109/JSSC.2016.2616357](https://doi.org/10.1109/JSSC.2016.2616357)

These works motivate special-purpose architectures that reduce control and data-movement overhead
for MAC-heavy workloads.

## Systolic Arrays and Dataflow

- B. Wang et al., "A novel systolic array processor with dynamic dataflows."
- A. Parashar et al., "Timeloop: A systematic approach to DNN accelerator evaluation," in
  *Proc. IEEE Int. Symp. Performance Analysis of Systems and Software (ISPASS)*, 2019,
  pp. 304–315. [doi:10.1109/ISPASS.2019.00042](https://doi.org/10.1109/ISPASS.2019.00042)

These sources cover the output-stationary, weight-stationary and input-stationary dataflows and
how each trades operand reuse against partial-sum movement. OS8 is output-stationary; the
reasoning behind that choice is in
[Background and Architecture](../docs/01-background-and-architecture.md).

## Google TPU

- N. P. Jouppi et al., "In-datacenter performance analysis of a Tensor Processing Unit," in
  *Proc. 44th Annu. Int. Symp. Computer Architecture (ISCA)*, 2017, pp. 1–12.
  [doi:10.1145/3079856.3080246](https://doi.org/10.1145/3079856.3080246)

TPU v1 is discussed as an industrial example of a large systolic matrix-multiplication
accelerator for inference.

## RISC-V and Rocket Chip

- A. Waterman and K. Asanović, Eds., *The RISC-V Instruction Set Manual, Volume I: Unprivileged
  ISA*. RISC-V Foundation. [riscv.org/technical/specifications](https://riscv.org/technical/specifications/)
- A. Waterman and K. Asanović, Eds., *The RISC-V Instruction Set Manual, Volume II: Privileged
  Architecture*. RISC-V Foundation.
- K. Asanović et al., "The Rocket Chip generator," EECS Department, University of California,
  Berkeley, Tech. Rep. UCB/EECS-2016-17, Apr. 2016.
  [www2.eecs.berkeley.edu/Pubs/TechRpts/2016/EECS-2016-17.html](https://www2.eecs.berkeley.edu/Pubs/TechRpts/2016/EECS-2016-17.html)

These provide the processor and custom-extension context for the project. The RoCC interface used
by OS8 is part of the Rocket Chip generator described in the last of these.

## Gemmini

- H. Genc et al., "Gemmini: Enabling systematic deep-learning architecture evaluation via
  full-stack integration," in *Proc. 58th ACM/IEEE Design Automation Conference (DAC)*, 2021,
  pp. 769–774. [doi:10.1109/DAC18074.2021.9586216](https://doi.org/10.1109/DAC18074.2021.9586216)

Gemmini is the major example of a RISC-V-integrated systolic-array accelerator using RoCC. OS8 is
not intended to replicate Gemmini's generator and memory architecture; it instead focuses on a
smaller fixed 8×8 accelerator that exposes the complete RTL and integration path.

## Tools and Frameworks

The implementation relies on:

- [Chipyard](https://github.com/ucb-bar/chipyard)
- [Rocket Chip](https://github.com/chipsalliance/rocket-chip)
- [Verilator](https://www.veripool.org/verilator/)
- SystemVerilog
- [GTKWave](https://gtkwave.sourceforge.net/)
- Synopsys Design Compiler
- SAED32nm educational standard-cell library

Refer to the respective upstream projects and tool documentation for installation and licensing
requirements. The SAED32nm library and Design Compiler both require licences that are not
included here.
