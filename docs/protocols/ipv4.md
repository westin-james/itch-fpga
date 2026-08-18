# IPv4 Decoder

## Purpose

Input: Ethernet payload containing an IPv4 packet  
Output: IPv4 payload, expected to contain a UDP datagram

The decoder parses the IPv4 header, filters packets that are not relevant to the configured feed, removes the IPv4 header and any options, and forwards the remaining payload downstream.

## Checks

- Version == 4
- IHL >= 5
- Protocol == UDP
- Destination IP == `expected_dest_ip`
- MF == 0
- Fragment Offset == 0
- Total Length >= Header Length

Packets that fail these checks are consumed but do not produce IPv4 payload output.

## Header / Payload Handling

The IPv4 header length is determined from IHL:

`header_length_bytes = IHL * 4`

This allows headers containing IPv4 options to be skipped without parsing the options themselves.

`total_length` determines which bytes belong to the IPv4 packet. Any Ethernet padding after `total_length` is consumed but not forwarded.

## Output Stream

- `ipv4_payload_valid` is asserted only for forwarded IPv4 payload bytes.
- `ipv4_payload_start` marks the first byte after the IPv4 header/options.
- `ipv4_payload_last` marks the final byte indicated by IPv4 Total Length.
- Input state advances only while `ethernet_payload_valid` is asserted.

## Current Limitations

- IPv4 header checksum is not currently verified.
- Fragmented IPv4 packets are rejected rather than reassembled.
- IPv4 options are skipped but not interpreted.

## Timing Considerations

The decoder accepts one input byte per cycle when `ethernet_payload_valid` is continuously asserted.

Payload bytes are forwarded combinationally once the decoder reaches `IPV4_PAYLOAD`.

Potential timing-sensitive logic includes the packet-acceptance checks, particularly the destination-IP comparison and other header validity checks. The actual critical path should be determined from synthesis and place-and-route results rather than assumed from the RTL.

## Potential Improvements

- Verify the IPv4 header checksum.
- Pipeline or restructure packet classification if timing requires it.
- Combine selected Ethernet/IPv4/UDP classification logic after the modular implementation has been measured.
- Add explicit malformed-packet/error counters.
- Support additional filtering criteria if useful.

## File Structure

- `rtl/packet_rx/ipv4/ipv4_pkg.sv` defines IPv4 constants, header fields, and decoder states.
- `rtl/packet_rx/ipv4/ipv4_decoder.sv` parses and filters IPv4 packets.
- `tb/packet_rx/ipv4/ipv4_decoder_tb.sv` tests the decoder.

## References

The packet format follows the [RFC 791 specification](https://datatracker.ietf.org/doc/html/rfc791).

Feed addressing information comes from the [Nasdaq UDP/IP Addresses documentation](https://www.nasdaqtrader.com/Trader.aspx?id=FeedIPS_Other).
