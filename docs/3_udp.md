# UDP decoder
input: IPv4 payload
output: UDP payload

The decoder removes the fixed eight-byte UDP header and forwards payload bytes
only when the packet's destination port matches `expected_dest_port`. The UDP
length field includes the header, so it also determines where the emitted
payload ends. Bytes that remain in the IPv4 payload after the declared UDP
length are treated as padding and are not forwarded.

For every accepted packet, `udp_payload_start` marks the first payload byte and
`udp_payload_last` marks the final payload byte. Both signals may be asserted on
the same cycle for a one-byte payload. State and byte counts advance only while
`ipv4_payload_valid` is asserted, so gaps are allowed in both the header and the
payload streams.

A truncated IPv4 payload terminates the UDP payload at `ipv4_payload_last`, even
when the UDP length declares more data. Truncated headers, packets for other
destination ports, and lengths of eight bytes or fewer produce no output. The
source port and checksum are captured from the header, but the checksum is not
validated.


## File structure

- `rtl/udp/udp_pkg.sv` defines the UDP header record and decoder states.
- `rtl/udp/udp_decoder.sv` parses the header, filters by destination port, and
  emits the bounded UDP payload stream.
- `tb/udp/udp_decoder.sv` checks port filtering, valid-stream gaps, declared
  lengths, truncated packets, padding, and back-to-back packet boundaries.


The packet format follows the
[RFC 768 specification](https://datatracker.ietf.org/doc/html/rfc768).
