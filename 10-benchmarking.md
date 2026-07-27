# Documentation

This directory contains the explanatory documentation for the OS8 accelerator.

The documentation is organised from general concepts to implementation details. A reader does not need prior knowledge of this project to begin with the first section.

## Suggested Reading Order

1. [Systolic arrays](01-systolic-arrays.md)
2. [Output-stationary dataflow](02-output-stationary.md)
3. [OS8 architecture](03-os8-architecture.md)
4. [CPA-factored processing element](04-cpa-factored-pe.md)
5. [RocketCore and RoCC](05-rocketcore-rocc.md)
6. [Custom instructions](06-custom-instructions.md)
7. [Operation flow](07-operation-flow.md)
8. [Memory and reuse](08-memory-and-data-reuse.md)
9. [Verification](09-verification.md)
10. [Benchmarking](10-benchmarking.md)
11. [Synthesis](11-synthesis.md)

## Scope

The OS8 accelerator is a fixed 8×8 signed-INT8 matrix-multiplication engine with 32-bit accumulation. It uses output-stationary systolic dataflow and a carry-save/CPA-factored arithmetic structure. It is attached to a RISC-V RocketCore as a RoCC coprocessor in Chipyard.

The documentation focuses on how this specific implementation works rather than attempting to document all of Rocket Chip, Chipyard, RISC-V, or neural-network accelerator architecture.
