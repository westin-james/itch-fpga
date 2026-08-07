# Event FIFO
input: market event
output: buffered market event

The asynchronous FIFO transfers normalized ITCH events from the parser clock
domain to an independently clocked downstream order book or event consumer.
The write and read sides use ready/valid handshakes. Binary pointers address the
memory, while Gray-coded pointers cross the clock-domain boundary through
two-stage synchronizers so only one pointer bit changes at a time.

If the parser presents an event while the FIFO is full, the event is not stored
and `wr_overflow` pulses in the write clock domain. The pipeline cannot apply
backpressure to the byte-stream parser, so downstream logic must treat this as
a lost event.


## File structure

- `rtl/event_fifo/event_fifo.sv` connects the memory, pointer handlers, and
  clock-domain synchronizers and exposes the ready/valid interface.
- `rtl/event_fifo/fifo_mem.sv` stores packed `itch_event_t` records, writes on
  accepted write-side transfers, and provides first-word fall-through read
  data.
- `rtl/event_fifo/wptr_handler.sv` advances the binary and Gray write pointers
  and detects the full condition using the synchronized Gray read pointer.
- `rtl/event_fifo/rptr_handler.sv` advances the binary and Gray read pointers
  and detects the empty condition using the synchronized Gray write pointer.
- `rtl/itch_pipeline.sv` connects the ITCH parser output to the FIFO write side
  and exposes the FIFO read side to the next processing stage.


## Design constraints

- `DEPTH` must be a power of two and at least four entries.
- Write-side state is synchronous to `wr_clk`; read-side state is synchronous
  to `rd_clk`.
- Only Gray-coded pointers cross between clock domains. The multi-bit binary
  pointers remain in their local domains.
- A write is accepted when `wr_valid && wr_ready`; a read is consumed when
  `rd_valid && rd_ready`.


The pointer scheme follows the asynchronous FIFO design described by
[VLSI Verify](https://vlsiverify.com/verilog/verilog-codes/asynchronous-fifo/).
