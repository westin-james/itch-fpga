# MoldUDP64 decoder
input: UDP payload with multiple ITCH messages
output: single ITCH message

The decoder removes the 20-byte MoldUDP64 header and splits the remaining UDP
payload into individual ITCH messages. Each message begins with a two-byte,
big-endian length. The length bytes are removed before the message is sent to
the ITCH parser.

For every output message, `itch_msg_start` marks the first byte,
`itch_msg_last` marks the final byte, and `itch_msg_length` holds the decoded
length. `itch_msg_valid` is asserted only for ITCH data bytes. Input state
advances only while `udp_payload_valid` is asserted, so gaps in the UDP stream
are allowed.

Packets with a message count of `0x0000` are heartbeats and packets with a
message count of `0xFFFF` mark the end of the session. Neither packet type
produces ITCH output.


## File structure

- `rtl/moldudp64/moldudp64_pkg.sv` defines the packet constants and decoder
  states.
- `rtl/moldudp64/moldudp64_decoder.sv` parses the header and emits one ITCH
  byte stream.
- `tb/moldudp64/moldudp64_decoder_tb.sv` checks two messages contained in one
  MoldUDP64 packet.


The packet format follows the
[NASDAQ MoldUDP64 specification](https://www.nasdaq.com/docs/moldudp64specv1.00.pdf).
