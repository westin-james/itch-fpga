# Ethernet Input Boundary

## Purpose

- Input: Raw Ethernet frame bytes
- Output: Ethernet payload, expected to contain an IPv4 packet

The Ethernet decoder identifies frames for the configured feed, removes the fixed Ethernet II header, and forwards accepted payload bytes to the IPv4 decoder. It is the first receive-side stage in `pipeline`:

`Ethernet decoder -> IPv4 decoder -> UDP decoder -> MoldUDP64 decoder -> ITCH parser`

The input stream begins at destination MAC byte 0. Ethernet preamble, start-frame delimiter, and frame check sequence are handled upstream and are not present on this interface.

## Checks

- Destination MAC address matches `expected_dest_mac`.
- EtherType == IPv4 (`0x0800`).
- The frame contains a complete Ethernet header.

Frames with a different destination MAC or EtherType are consumed without producing payload output. Frames ending before the complete 14-byte header also produce no output, and the decoder returns to its idle state at the frame boundary.

## Header / Payload Handling

The decoder consumes the fixed 14-byte Ethernet II header:

- Destination MAC: 6 bytes
- Source MAC: 6 bytes
- EtherType: 2 bytes

For an accepted frame, the byte immediately following EtherType is emitted with `ethernet_payload_start`. The input `frame_last` marker is passed through as `ethernet_payload_last` when it accompanies an accepted payload byte.

Ethernet II does not carry a payload-length field, so the decoder forwards any Ethernet padding at the end of an accepted frame. The IPv4 decoder uses IPv4 Total Length to consume but not forward that padding.

## Output Stream

- `frame_valid` indicates that `data_in` contains an Ethernet frame byte.
- `frame_start` marks destination MAC byte 0.
- `frame_last` marks the final frame byte after the FCS has been removed upstream.
- `ethernet_payload_valid` is asserted only for accepted payload bytes.
- `ethernet_payload_start` marks the first payload byte.
- `ethernet_payload_last` marks the final byte of the accepted frame.

Input state advances only while `frame_valid` is asserted, so valid gaps are preserved without changing header or payload position. The interface has no ready signal and cannot apply backpressure to the upstream source.

## Current Limitations

- Only untagged Ethernet II frames are supported; IEEE 802.1Q VLAN tags are not parsed.
- Only one exact destination MAC address is accepted. Broadcast, multicast, and multiple configured addresses are not supported separately.
- The frame check sequence is not verified because it is removed upstream.
- Malformed and filtered frames do not produce status flags or counters.
- A missing `frame_last` cannot be detected internally; the upstream source must provide packet boundaries.

## Timing Considerations

The decoder accepts at most one frame byte per `parser_clk` cycle and can accept valid bytes on consecutive cycles. Back-to-back frames are supported when the next frame's `frame_start` follows the preceding frame's `frame_last` on the next cycle.

Accepted payload bytes are forwarded combinationally once the decoder reaches `ETH_PAYLOAD`. MAC and EtherType filtering occurs while the fixed header arrives. The actual critical path should be determined from synthesis and place-and-route results.

## Potential Improvements

- Support IEEE 802.1Q VLAN tags if required by the feed network.
- Add malformed-frame and filtered-frame counters.
- Integrate the selected FPGA MAC/PHY interface and clock-domain crossing.
- Support multiple destination MAC addresses or multicast matching if required.

## File Structure

- `rtl/packet_rx/ethernet/ethernet_pkg.sv` defines the IPv4 EtherType, header fields, and decoder states.
- `rtl/packet_rx/ethernet/ethernet_decoder.sv` parses, filters, and removes Ethernet II headers.
- `tb/packet_rx/ethernet/ethernet_decoder_tb.sv` tests accepted and filtered frames, valid gaps, start/last behavior, back-to-back frames, padding, and truncated boundaries.
- `rtl/top/pipeline.sv` connects the Ethernet decoder output to the IPv4 decoder.
- `tb/top/pipeline_tb.sv` exercises the complete Ethernet-to-ITCH receive pipeline, including MAC/EtherType filtering and Ethernet padding.
- `make test-ethernet` runs the dedicated Ethernet decoder simulation.

## References

Ethernet framing is defined by the [IEEE 802.3 Ethernet standard](https://standards.ieee.org/ieee/802.3/10422/).
