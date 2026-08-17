# UDP Decoder

## Purpose

Input: IPv4 payload containing a UDP datagram  
Output: UDP payload, expected to contain a MoldUDP64 packet

The decoder parses and removes the fixed eight-byte UDP header, filters datagrams by destination port, and forwards only the payload bytes declared by UDP Length.

## Checks

- Destination Port == `expected_dest_port`
- UDP Length > 8 bytes
- The complete eight-byte UDP header is present

Datagrams that fail these checks are consumed but do not produce output. A UDP Length of eight represents an empty payload and is not forwarded.

## Header / Payload Handling

UDP Length includes both header and payload:

`payload_length_bytes = udp_length - 8`

Bytes after the declared length are treated as IPv4 padding and consumed without being forwarded. If `ipv4_payload_last` arrives before the declared length, the decoder terminates the output on that byte.

The source port and checksum are captured but do not affect packet acceptance.

## Output Stream

- `udp_payload_valid` is asserted only for bytes from an accepted datagram.
- `udp_payload_start` marks the first byte after the UDP header.
- `udp_payload_last` marks the byte selected by UDP Length or an earlier `ipv4_payload_last`.
- A one-byte payload asserts start and last together.
- Input state advances only while `ipv4_payload_valid` is asserted, so valid gaps are allowed.

## Current Limitations

- The UDP checksum is not verified.
- Source-port filtering is not supported.
- Truncated payloads are forwarded and terminated rather than rejected or reported.
- Empty UDP payloads produce no explicit output indication.
- Malformed-packet and filtered-packet counters are not provided.

## Timing Considerations

The decoder accepts one input byte per cycle when `ipv4_payload_valid` is continuously asserted.

Payload bytes are forwarded combinationally in `UDP_PAYLOAD`. End detection compares the byte count with the captured length, and acceptance depends on the destination-port comparison performed during the header.

The actual critical path should be determined from synthesis and place-and-route results.

## Potential Improvements

- Verify the UDP checksum when required.
- Reject and report datagrams truncated relative to UDP Length.
- Add optional source-port filtering.
- Add malformed, filtered, and checksum-error counters.
- Pipeline the payload-length comparison if timing requires it.

## File Structure

- `rtl/udp/udp_pkg.sv` defines the UDP header record and decoder states.
- `rtl/udp/udp_decoder.sv` parses, filters, and emits the bounded payload stream.
- `tb/udp/udp_decoder.sv` tests filtering, valid gaps, lengths, truncation, padding, and packet boundaries.

## References

The packet format follows the [RFC 768 specification](https://datatracker.ietf.org/doc/html/rfc768).
