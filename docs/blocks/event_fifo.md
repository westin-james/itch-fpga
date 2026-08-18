# Event FIFO

## Purpose

Input: Normalized ITCH events in the parser clock domain  
Output: Buffered events in an independent consumer clock domain

The asynchronous FIFO decouples the parser from a downstream order book or consumer. Binary pointers address storage, while Gray-coded pointers cross clock domains through two-stage synchronizers.

## Checks

- `DEPTH` is a power of two.
- `DEPTH` is at least four entries.
- Writes occur only while the FIFO is not full.
- Reads advance only while the FIFO is not empty.

Depth constraints are checked at elaboration. A write presented while full is rejected and causes `wr_overflow` to pulse.

## Event / Clock-Domain Handling

A write is accepted when:

`wr_valid && wr_ready`

A read is consumed when:

`rd_valid && rd_ready`

Binary pointers remain local. Gray pointers cross domains through two registers marked `ASYNC_REG`. Full detection inverts the two most-significant synchronized read-pointer bits; empty detection compares the next Gray read pointer with the synchronized write pointer.

Memory is first-word fall-through, so `rd_data` reflects the current entry without a separate read-enable cycle.

## Output Stream

- `wr_ready` is deasserted while full.
- `wr_overflow` pulses in the write domain for each rejected `wr_valid` cycle.
- `rd_valid` is asserted while not empty.
- `rd_data` stays associated with the current read pointer until an accepted read.
- Events are delivered in accepted write order.

## Current Limitations

- The byte-stream parser cannot be backpressured, so overflow causes irreversible event loss.
- No occupancy, almost-full, or almost-empty indication is provided.
- Overflow is a pulse rather than sticky status or a counter.
- Reset sequencing across domains is left to the integrating design.
- The generic RTL does not instantiate a vendor-specific dual-port memory.

## Timing Considerations

Write state is synchronous to `wr_clk`; read state is synchronous to `rd_clk`. Synchronization adds two destination-clock cycles before activity in one domain affects status in the other.

The combinational memory read enables first-word fall-through but may affect timing or memory inference. Full and empty detection also include Gray conversion and pointer comparison.

Critical paths and memory implementation should be determined from synthesis and place-and-route results for the target.

## Potential Improvements

- Add occupancy-based almost-full and almost-empty thresholds.
- Add sticky overflow status and a lost-event counter.
- Define and verify a system-level reset sequence.
- Add assertions or formal checks for pointer safety, ordering, overflow, and underflow.
- Wrap a vendor asynchronous FIFO primitive when its guarantees or inference are preferable.
- Size the FIFO from measured worst-case producer and consumer rates.

## File Structure

- `rtl/event/event_fifo/event_fifo.sv` connects memory, pointers, synchronizers, and interfaces.
- `rtl/event/event_fifo/fifo_mem.sv` stores `itch_event_t` records and provides first-word fall-through data.
- `rtl/event/event_fifo/wptr_handler.sv` advances write pointers and detects full.
- `rtl/event/event_fifo/rptr_handler.sv` advances read pointers and detects empty.
- `rtl/top/pipeline.sv` connects the parser to the write side and exposes the read side.
- `tb/event/event_fifo/event_fifo_tb.sv` tests asynchronous ordering, full behavior, and overflow.

## References

The pointer scheme follows Clifford E. Cummings's [Simulation and Synthesis Techniques for Asynchronous FIFO Design](https://www.sunburst-design.com/papers/CummingsSNUG2002SJ_FIFO1.pdf).
