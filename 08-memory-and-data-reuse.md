# CPA-Factored Processing Element

## Motivation

A straightforward MAC datapath is:

```text
accumulator <= accumulator + A × B
```

If the accumulator is wide, that structure requires carry propagation through an adder on every accumulation cycle.

OS8 instead keeps the running result in carry-save form during the repeated MAC phase and performs the full carry-propagate addition only when a completed result leaves the mesh.

This is the central idea behind the CPA-factored arithmetic structure used by the accelerator.

## Carry-Save Representation

Rather than storing one conventional accumulated number, the PE stores two vectors:

```text
sum
carry
```

Together they represent the accumulated value.

The next product is merged into these vectors without requiring full carry propagation across the entire accumulator width on every cycle.

The normal binary value is recovered later by:

\[
result = sum + carry
\]

using `os8_final_cpa`.

## PE Datapath

Conceptually:

```text
 a_in ──┐
        × ── product ── sign extend ──┐
 b_in ──┘                              │
                                      ▼
                               carry-save update
                                  │         │
                                  ▼         ▼
                                 sum       carry
```

The operands are signed INT8 and the accumulated result is 32 bits.

## Why Two Carry-Save Banks?

Each PE contains two internal carry-save banks.

At any given phase:

- one bank can be assigned to computation,
- the other can be assigned to result propagation.

`prop_sel` selects the roles.

This enables a completed carry-save result to be shifted down the column while the PE structure retains the alternate bank for the other role.

The design therefore separates the **compute representation** from the **final carry-propagate conversion**.

## Propagation Interface

Each PE has:

- `prop_sum_in`
- `prop_carry_in`
- `prop_sum_out`
- `prop_carry_out`

During the propagation phase, a PE receives the pair from the PE above and forwards its selected propagation pair toward the PE below.

At the bottom row, the mesh exposes these signals to the final CPA stage.

```text
PE row 0
   │ sum/carry
   ▼
PE row 1
   │
   ▼
PE row 2
   │
   ▼
...
   │
   ▼
bottom_sum / bottom_carry
   │
   ▼
os8_final_cpa
```

## Final CPA

`os8_final_cpa` performs the ordinary carry-propagate addition after the result has reached the bottom of the mesh.

```text
result_out = sum_in + carry_in
```

In `os8_sa`, one final CPA is instantiated for each output column.

## What This Optimisation Does and Does Not Mean

The design does not remove carry propagation entirely. A normal binary result still requires a final CPA.

Instead, the design **factors the CPA out of the repeated accumulation path** so that the PE does not need to perform a wide carry-propagating addition for every MAC update.

## Relationship to Output-Stationary Dataflow

During the compute phase, each PE is still responsible for accumulating the output associated with its position, so the dataflow remains output stationary.

Carry-save representation is an arithmetic implementation choice inside that OS organisation.

## Source Files

- `rtl/os8_pe.sv`
- `rtl/os8_pe_mesh.sv`
- `rtl/os8_final_cpa.sv`
- `rtl/os8_sa.sv`
