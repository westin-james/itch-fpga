# ITCH FPGA parser

The RTL parses all NASDAQ ITCH order messages: Add Order (`A`), Add Order with
MPID Attribution (`F`), Executed (`E`), Executed with Price (`C`), Cancel
(`X`), Delete (`D`), and Replace (`U`). It accepts one byte per clock.

`itch_parser` presents these routes as one normalized packed event interface
for a downstream FIFO. `event_valid` pulses for one cycle,
`event_data.event_type` identifies the original ITCH type, and the common
payload fields have the following meaning:

| Event | `order_reference` | `new_order_reference` | `shares` | `price` |
| --- | --- | --- | --- | --- |
| A/F | new order | 0 | added | limit price |
| E | executed order | 0 | executed | 0 |
| C | executed order | 0 | executed | execution price |
| X | canceled order | 0 | canceled | 0 |
| D | deleted order | 0 | 0 | 0 |
| U | original order | replacement order | replacement | replacement price |

Fields that do not apply to the current event are zero. Every specialized
parser uses the same `event_valid` plus `itch_event_t` interface; the dispatcher
multiplexes those records without maintaining a second flattened interface.

Shared message identifiers, message lengths, and the packed event record live
in `itch_event_pkg`. The parser emits `itch_event_pkg::itch_event_t event_data`.
System-wide architectural defaults live in `rtl/common/sys_defs_pkg.sv` and are used
with fully qualified names as overridable module-parameter defaults. Each
definition documents its constraints and consumers so references remain easy
to trace.
`event_fifo` transfers that record between independent parser and consumer
clocks using Gray-coded pointers and two-stage synchronizers. Its depth is
configurable and must be a power of two.

`itch_pipeline` is the current integration boundary. It connects the parser's
normalized event output directly to the asynchronous FIFO and exposes a
ready/valid event stream for a future CPU, order book, or trading core. The
pipeline also exposes parse, unsupported-message, and overflow status signals.
Because the parser has no input backpressure, `fifo_overflow`
means an event was lost and must not be ignored.

## Verify the RTL

The simulation and lint steps are independent of any FPGA vendor:

```sh
make test
make lint
```

Simulation uses Icarus Verilog; lint uses Verilator. Generated files go under
`build/`.

## Synthesis and timing

There are two intentionally separate workflows.

### 1. Generic synthesis check

With Yosys installed:

```sh
make synth-yosys
```

The cell/resource summary and full log are written to
`build/synth/yosys/synthesis.log`. This is useful for catching synthesis errors
and comparing RTL revisions, but generic synthesis does **not** predict the
maximum clock frequency of a particular FPGA.

### 2. Post-route timing for an AMD/Xilinx FPGA

Use the exact orderable part number for the intended device and speed grade:

```sh
make timing-vivado PART=xc7a35tcsg324-1 PERIOD_NS=10.000
```

This runs a non-project, out-of-context Vivado flow: synthesis, placement,
physical optimization, routing, then static timing analysis. Results are in:

- `build/pnr/vivado/fmax_summary.txt` — WNS and an estimated Fmax
- `build/pnr/vivado/timing_summary.rpt` — detailed timing paths and checks
- `build/pnr/vivado/utilization.rpt` — device resource use
- `build/pnr/vivado/itch_parser_<part>.dcp` — routed checkpoint

`PERIOD_NS` is the timing target, not a claim about achievable speed. Start at
10 ns (100 MHz), inspect the result, and rerun near the estimated critical
period. A non-negative WNS means that routed build met the requested period.
For example:

```sh
make timing-vivado PART=xc7a35tcsg324-1 PERIOD_NS=5.000
```

Keep the Vivado version, `PART`, and `PERIOD_NS` in benchmark records. Tool and
device versions can change placement and timing results.

The supplied timing flow measures the parser as an isolated core. It constrains
register-to-register paths but not external input/output delays. The final
system clock can differ after the parser is integrated with its Ethernet input,
downstream logic, pin constraints, and clocking resources. For a board-level
answer, instantiate this core in the real top-level design and run timing with
the board's XDC constraints.

## Turning clock frequency into throughput

The input interface accepts at most one byte each cycle, with no backpressure.
At `F` MHz its peak payload rate is therefore:

- `F` MB/s, or `0.008 * F` Gbit/s
- `F / message_length` million messages/s for a continuous stream

At 100 MHz, for example, that is 100 MB/s (0.8 Gbit/s), about 2.78 million `A`
messages/s, or 2.5 million `F` messages/s. This is payload throughput and does
not include Ethernet/IP/UDP/MoldUDP64 overhead or gaps between messages.

## Other FPGA families

Maximum frequency is device- and speed-grade-specific. For Intel, Lattice, or
another family, keep `make test` and `make lint`, then replace the Vivado target
with that vendor's place-and-route flow. Use the same principles: exact part,
explicit clock constraint, post-route timing report, and checked-in scripts.
