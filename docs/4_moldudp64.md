# MoldUDP64 Decoder

## Purpose

Input: UDP payload containing a MoldUDP64 packet  
Output: Individual length-bounded ITCH message streams

The decoder removes the 20-byte MoldUDP64 header, removes each two-byte message-length prefix, and emits each contained ITCH message separately.

## Checks

- Message Count != heartbeat value (`0x0000`)
- Message Count != end-of-session value (`0xFFFF`)
- Message Length != 0 before entering message-data state

Heartbeat and end-of-session packets are consumed without producing output. A zero-length message entry is skipped.

## Header / Payload Handling

The fixed header contains a ten-byte session identifier, eight-byte sequence number, and two-byte message count. The decoder consumes session and sequence without storing or validating them, and captures only Message Count.

Each message has a two-byte, big-endian length followed by that many ITCH bytes. The prefix is removed:

`itch_message_bytes = message_length`

After a message's final byte, the decoder returns to the length state unless the UDP payload also ends.

## Output Stream

- `itch_msg_valid` is asserted only for ITCH data bytes.
- `itch_msg_start` marks the first byte after a length prefix.
- `itch_msg_last` marks the byte selected by Message Length.
- `itch_msg_length` holds the decoded length throughout the message.
- A one-byte message asserts start and last together.
- Input state advances only while `udp_payload_valid` is asserted, so valid gaps are allowed.

## Current Limitations

- Message Count is used only to recognize heartbeat and end-of-session packets; it is not compared with the number decoded.
- Session and sequence are not exposed or checked, so packet loss and reordering are not detected.
- Truncated headers, length fields, and messages are not explicitly reported or recovered in every state.
- A message extending beyond the UDP payload is not rejected before bytes are emitted.
- Retransmission requests are not supported.

## Timing Considerations

The decoder accepts one input byte per cycle when `udp_payload_valid` is continuously asserted.

ITCH bytes and boundary flags are produced combinationally in `MOLD_MSG_DATA`. Boundary logic compares the running count with the captured 16-bit length.

The actual critical path should be determined from synthesis and place-and-route results.

## Potential Improvements

- Verify that the packet contains exactly Message Count messages.
- Expose session and sequence for gap detection and recovery.
- Detect and report truncated or malformed packets.
- Define recovery when `udp_payload_last` arrives in header or length states.
- Add heartbeat, end-of-session, sequence-gap, and malformed-packet counters.

## File Structure

- `rtl/moldudp64/moldudp64_pkg.sv` defines constants, the header record, and decoder states.
- `rtl/moldudp64/moldudp64_decoder.sv` removes framing and emits individual ITCH messages.
- `tb/moldudp64/moldudp64_decoder_tb.sv` tests two messages in one MoldUDP64 packet.

## References

The packet format follows the [Nasdaq MoldUDP64 specification](https://www.nasdaq.com/docs/moldudp64specv1.00.pdf).
