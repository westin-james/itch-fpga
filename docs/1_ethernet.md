# Ethernet Input Boundary

## Purpose

Input: Raw Ethernet frame bytes  
Output: Ethernet payload, expected to contain an IPv4 packet

The intended Ethernet stage identifies frames for the configured feed, removes the Ethernet header, and forwards the Ethernet payload to the IPv4 decoder. This stage is not currently implemented; `pipeline` accepts a pre-stripped Ethernet payload directly.

## Checks

A future Ethernet decoder should check:

- Destination MAC address matches the configured feed, when filtering is enabled.
- EtherType == IPv4 (`0x0800`).
- The frame contains a complete Ethernet header.

No Ethernet checks are performed by the current RTL. The upstream source must supply the intended Ethernet payloads.

## Header / Payload Handling

A future decoder should remove the destination MAC address, source MAC address, and EtherType. Handling for optional VLAN tags must be defined before tagged frames can be accepted.

The current `pipeline` input starts at the first IPv4-header byte. Ethernet preamble, start-frame delimiter, frame check sequence, and interpacket gap are outside the interface.

## Output Stream

- `data_valid` indicates that `data_in` contains an Ethernet payload byte.
- `data_start` marks the first IPv4-header byte.
- `data_last` marks the final byte supplied by the upstream Ethernet source.
- The interface has no ready signal, so the upstream source cannot be backpressured.

These signals connect directly to the `ethernet_payload_*` inputs of `ipv4_decoder`.

## Current Limitations

- No Ethernet decoder exists in the current RTL.
- MAC addresses, EtherType, and VLAN tags are not parsed.
- The frame check sequence is not verified.
- The upstream component must remove Ethernet framing and provide packet boundaries.

## Timing Considerations

The downstream pipeline accepts at most one payload byte per `parser_clk` cycle. A future Ethernet stage must preserve valid gaps and the start/last markers expected by the IPv4 decoder.

MAC and EtherType filtering can occur while the fixed header arrives. The critical path and required buffering should be measured after the Ethernet stage and physical interface are selected.

## Potential Improvements

- Implement configurable destination-MAC and EtherType filtering.
- Support IEEE 802.1Q VLAN tags if required by the feed network.
- Add malformed-frame and filtered-frame counters.
- Integrate the selected FPGA MAC/PHY interface and clock-domain crossing.
- Decide whether frame check sequence validation belongs in the FPGA MAC or this stage.

## File Structure

- `rtl/pipeline.sv` exposes the current pre-stripped Ethernet payload input.
- `tb/pipeline.sv` supplies IPv4 packets directly at that boundary.
- No `rtl/ethernet` implementation or dedicated Ethernet testbench exists.

## References

Ethernet framing is defined by the [IEEE 802.3 Ethernet standard](https://standards.ieee.org/ieee/802.3/10422/).
