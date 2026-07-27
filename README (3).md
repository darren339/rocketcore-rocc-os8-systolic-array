# References and Related Work

This project builds on established work in neural-network accelerator architecture, systolic arrays, RISC-V, Rocket Chip, and RoCC.

The project report discusses the following major topics and sources.

## Neural-Network Accelerator Architecture

- V. Sze, Y.-H. Chen, T.-J. Yang, and J. Emer, *Efficient Processing of Deep Neural Networks: A Tutorial and Survey*.
- W. J. Dally, *Domain-Specific Hardware Accelerators*.
- Y.-H. Chen et al., *Eyeriss: An Energy-Efficient Reconfigurable Accelerator for Deep Convolutional Neural Networks*.

These works motivate special-purpose architectures that reduce control and data-movement overhead for MAC-heavy workloads.

## Systolic Arrays and Dataflow

- B. Wang et al., *A Novel Systolic Array Processor with Dynamic Dataflows*.
- A. Parashar et al., *Timeloop: A Systematic Approach to DNN Accelerator Evaluation*.

The report uses output-stationary, weight-stationary, and input-stationary dataflows to explain how different choices trade operand reuse against partial-sum movement.

## Google TPU

- N. P. Jouppi et al., *In-Datacenter Performance Analysis of a Tensor Processing Unit*.

TPU v1 is discussed as an industrial example of a large systolic matrix-multiplication accelerator for inference.

## RISC-V and Rocket Chip

- RISC-V Instruction Set Manual
- RISC-V Privileged Architecture
- A. Waterman et al., *The RISC-V Rocket Chip Generator*

These references provide the processor and custom-extension context for the project.

## Gemmini

- H. Genc et al., *Gemmini: Enabling Systematic Deep-Learning Architecture Evaluation via Full-Stack Integration*.

Gemmini is a major example of a RISC-V-integrated systolic-array accelerator using RoCC. OS8 is not intended to replicate Gemmini's full generator and memory architecture; it instead focuses on a smaller fixed 8×8 accelerator that exposes the complete RTL and integration path.

## Tools / Frameworks

The implementation also relies on:

- Chipyard
- Rocket Chip
- Verilator
- SystemVerilog
- GTKWave
- Synopsys Design Compiler
- SAED32nm educational standard-cell library

Refer to the respective upstream projects and tool documentation for installation and licensing requirements.
