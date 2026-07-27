# Complete Operation Flow

This page follows one matrix multiplication from software preparation to accelerator completion.

## 1. Software Prepares the Workload

The hardware datapath always computes an 8×8 tile.

For a matrix smaller than 8×8, software places the valid elements into an 8×8 tile buffer and fills unused positions with zero.

For matrices larger than 8×8, software breaks the full operation into repeated 8×8 tile multiplications.

## 2. Software Sets Buffer Addresses

RoCC configuration instructions provide:

- A tile address
- B tile address
- C tile address

Optional activation configuration is also sent.

## 3. Software Issues an Execution Command

The simplest path uses the full-operation command.

```text
Load A → Load B → Compute → Store C
```

For reuse-oriented execution, software can instead invoke the stages separately.

## 4. Controller Loads Matrix A

The controller sends memory-read requests beginning at `aPtr`.

Returned data is written into the internal A tile buffer.

The physical systolic core therefore receives a complete local 8×8 A tile rather than fetching individual operands directly.

## 5. Controller Loads Matrix B

The equivalent sequence occurs for B using `bPtr`.

If B was previously loaded and is intended to be reused, this stage can be skipped.

## 6. Controller Starts `os8_sa`

The controller asserts `core_start`.

`os8_sa` loads the input matrices into the systolic input structures and begins its internal compute sequence.

## 7. B Is Transposed

The B matrix is converted into `B_T` for the top-side stream generator.

This aligns each original B column with one delay-memory lane.

## 8. Delay Memories Generate the Wavefront

Two `os8_delay_mem` instances create staggered A and B streams.

A enters from the left.

B enters from the top.

The skew guarantees that each PE receives the intended `A[i][k]` and `B[k][j]` pair on the same cycle.

## 9. The PE Mesh Performs MAC Operations

Each of the 64 PEs multiplies signed INT8 operands.

Partial results are accumulated in 32-bit carry-save form.

During this phase, A moves right and B moves down.

## 10. Completed Carry-Save Results Propagate Downward

After the compute wavefront has completed, the selected carry-save bank is propagated vertically through the mesh.

The bottom row exposes one sum/carry pair per column.

## 11. Final CPA Converts the Result

`os8_final_cpa` adds the carry-save sum and carry vectors.

The resulting signed 32-bit values are captured into output matrix C.

## 12. Controller Selects Output Elements

The controller reads the computed C matrix and prepares each value for storage.

## 13. Output Processing

The activation unit first performs an arithmetic right shift.

If ReLU is enabled and the shifted result is negative, the value is replaced by zero.

## 14. C Is Written to Memory

The controller issues memory-write requests beginning at `cPtr`.

## 15. RoCC Response Is Returned

After the selected operation is complete, the controller returns a response to RocketCore using the stored destination register.

The response data is also used for accelerator-cycle information in the test software.

## 16. Software Continues the Tiled Matrix Operation

If more tiles are required, software prepares or reuses the next operand tiles and invokes the accelerator again.

Partial C tiles are accumulated by software when the full matrix multiplication spans multiple K tiles.

## Summary

```text
matrix workload
    ↓
software tiling / zero padding
    ↓
RoCC configuration
    ↓
load A/B
    ↓
delay / skew
    ↓
8×8 OS systolic compute
    ↓
carry-save propagation
    ↓
final CPA
    ↓
shift / ReLU
    ↓
store C
    ↓
RoCC response
```
