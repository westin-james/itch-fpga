# ITCH Parser

## Purpose

Input: One raw Nasdaq TotalView-ITCH 5.0 message  
Output: One normalized order-book event

The dispatcher selects a specialized parser from the first byte. Supported order messages become a shared packed event record; unsupported types are consumed without producing an event.

## Checks

- Message Type is `A`, `F`, `E`, `C`, `X`, `D`, or `U` before an event is produced.
- MoldUDP64 Message Length matches the fixed length for the selected type.
- `data_last` occurs at the expected final byte index.
- A non-start byte arrives only while a route is active.
- A new `data_start` does not arrive while the previous route is active.

Supported messages that fail checks do not produce an event and pulse `parse_error`. Unsupported messages pulse `unsupported_message` when their final byte is consumed, without asserting `parse_error` solely for their type.

## Message / Event Handling

| ITCH type | Event | Distinct normalized fields |
| --- | --- | --- |
| `A` | Add Order | order reference, side, shares, stock, price |
| `F` | Add Order with MPID | `A` fields, MPID, `has_mpid` |
| `E` | Order Executed | order reference, executed shares, match number |
| `C` | Executed with Price | `E` fields, printable, price, `has_execution_price` |
| `X` | Order Cancel | order reference, canceled shares |
| `D` | Order Delete | order reference |
| `U` | Order Replace | old and new references, replacement shares, price |

Every route also captures Stock Locate, Tracking Number, and Timestamp. Non-applicable fields are cleared before `event_valid`. Multi-byte fields are decoded in network byte order.

## Output Stream

- `event_valid` pulses for one cycle when a supported message passes all checks.
- `event_data.event_type` preserves the ITCH message type.
- `event_data` uses `itch_event_pkg::itch_event_t` for every route.
- `unsupported_message` and `parse_error` are one-cycle status pulses.
- State advances only while `data_valid` is asserted, so valid gaps are allowed.
- The input has no ready signal and cannot be backpressured.

## Current Limitations

- Only order messages `A`, `F`, `E`, `C`, `X`, `D`, and `U` are decoded.
- System, directory, state, trade, auction, and administrative messages are discarded.
- The parser normalizes messages but does not maintain order-book state.
- Errors are pulses without counters or detailed codes.
- Backpressure cannot be applied to the incoming byte stream.

## Timing Considerations

The parser accepts one byte per cycle when `data_valid` is continuous. Specialized parsers accumulate fields in registers and emit a registered event after the final byte.

The dispatcher drives the selected parser and multiplexes event outputs through a fixed-priority combinational chain. Valid routes cannot normally finish together, so priority is defensive rather than expected arbitration.

The actual critical path should be determined from synthesis and place-and-route results.

## Potential Improvements

- Decode ITCH types needed for book initialization and market-state handling.
- Add detailed error codes and per-message-type counters.
- Add input buffering or a ready/valid contract.
- Generate parsers from a declarative message schema to reduce repeated index logic.
- Pipeline the output multiplexer if timing requires it.

## File Structure

- `rtl/itch/itch_event_pkg.sv` defines identifiers, lengths, and the event record.
- `rtl/itch/itch_parser.sv` dispatches messages and multiplexes events.
- `rtl/itch/itch_parser_add.sv` decodes `A` and `F`.
- `rtl/itch/itch_parser_execute.sv` decodes `E` and `C`.
- `rtl/itch/itch_parser_cancel.sv`, `rtl/itch/itch_parser_delete.sv`, and `rtl/itch/itch_parser_replace.sv` decode `X`, `D`, and `U`.
- `tb/itch/itch_parser_tb.sv` tests routing, normalized fields, unsupported messages, bad lengths, and routing errors.

## References

The formats follow the [Nasdaq TotalView-ITCH 5.0 specification](https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification_5.0.pdf).
