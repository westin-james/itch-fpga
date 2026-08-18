# Order Book Integration Boundary

## Purpose

Input: Buffered normalized ITCH events  
Output: Maintained order-book state for trading logic or a host interface

The intended order-book stage consumes the event stream produced by `event_fifo` and applies each normalized event to book state. No order-book RTL is currently implemented, and the state representation and downstream interface have not been selected.

## Required Checks

A future implementation should check:

- Referenced orders exist for execute, cancel, delete, and replace events.
- Add and replacement references are not already active.
- Executed or canceled shares do not exceed the remaining quantity.
- Side values are valid for add events.
- Price and stock identifiers map to supported storage.
- Feed sequence continuity has been established before events reach the book.

The current pipeline performs none of these stateful checks.

## Event / Book Handling

| ITCH type | Required operation |
| --- | --- |
| `A`, `F` | Insert a new order with side, shares, stock, and price. |
| `E`, `C` | Reduce executed shares; remove the order when depleted. |
| `X` | Reduce canceled shares; remove the order when depleted. |
| `D` | Remove the referenced order. |
| `U` | Replace the old reference with the new reference, shares, and price. |

An event is accepted when `event_valid && event_ready`. Deasserting `event_ready` stalls FIFO reads but not the upstream parser; a prolonged stall can fill the FIFO and cause event loss.

## Output Interface

No order-book output interface is defined. Possible consumers include trading logic, a PCIe or host-visible snapshot path, and monitoring or replay logic.

The design must first choose whether to emit individual updates, best bid/offer changes, depth snapshots, direct memory access, or a combination.

## Current Limitations

- No order-book module or testbench exists.
- MoldUDP64 session and sequence information is discarded, so the book cannot detect feed gaps.
- Stock-directory and trading-state messages are not decoded.
- Storage capacity, collision behavior, recovery policy, and downstream interface are unspecified.

## Timing Considerations

The event FIFO permits the order book to use a clock independent of `parser_clk`. Required throughput depends on feed rate, FIFO depth, memory architecture, and cycles per operation.

Hash lookup, price-level aggregation, and external-memory access are likely timing concerns, but the critical path cannot be assessed until an architecture and FPGA target are chosen.

## Potential Improvements

- Define whether the book stores per-order state, aggregated price levels, or both.
- Preserve MoldUDP64 session and sequence information and stop updates after an unresolved gap.
- Decode the ITCH directory and market-state messages needed for initialization.
- Choose bounded storage and define capacity-exhaustion behavior.
- Specify trading-core and host-observation interfaces.
- Compare RTL book state with a software model during feed replay.

## File Structure

- `rtl/event/itch/itch_event_pkg.sv` defines the normalized event record.
- `rtl/event/event_fifo/event_fifo.sv` provides the ready/valid event source.
- `rtl/top/pipeline.sv` exposes `event_valid`, `event_ready`, and `event_data`.
- `rtl/book/order_book_pkg.sv` is reserved for shared book events, order entries, enums, and constants.
- `rtl/book/order_book.sv` is the planned top-level wrapper for the book subsystem.
- `rtl/book/order_book_update_engine.sv` will interpret events and coordinate state updates.
- `rtl/book/order_lookup.sv` will map order IDs to side, price, and remaining quantity.
- `rtl/book/price_level_book.sv` will maintain aggregated quantity by price level.
- `rtl/book/bbo_tracker.sv` will maintain the best bid and offer.
- These RTL files are currently empty, and no dedicated testbench exists.

## References

Event semantics follow the [Nasdaq TotalView-ITCH 5.0 specification](https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification_5.0.pdf).
