# OS8 Technical Documentation

This documentation is the long-form technical companion to the source code.

Instead of splitting the project into many short pages, the documentation is consolidated into three larger sections:

1. [Background and Architecture](01-background-and-architecture.md)  
   Why systolic arrays are used, how output-stationary dataflow works, and how the OS8 hardware is structured.

2. [RocketCore Integration, Operation and Verification](02-integration-operation-and-verification.md)  
   How RocketCore communicates with OS8 through RoCC, how custom instructions control the accelerator, how matrix tiling and reuse work, and how the design was verified.

3. [Performance, Scalability and Synthesis](03-performance-scalability-and-synthesis.md)  
   Benchmark results, interpretation of the speedup behaviour, theoretical throughput, scalability with larger arrays and SRAM macros, and final synthesis results.

The intention is that a reader can move from these documents directly into the RTL, Scala and C source code.
