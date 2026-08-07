# ITCH parser
input: raw ITCH message
output: normalized decoded market event

The dispatcher supports every order-book route (`A`, `F`, `E`, `C`, `X`, `D`,
and `U`). Each specialized parser validates the MoldUDP64 message length and
byte count. Every parser emits the same packed event type, and the dispatcher
multiplexes those records onto one `event_valid`/`event_data` interface.
Non-applicable fields are cleared before the record reaches the event FIFO.


## File structure

- `rtl/itch/itch_event_pkg.sv` defines the shared message constants, lengths,
  and packed event record.
- `rtl/itch/itch_parser.sv` dispatches each packet based on its first byte and
  routes bytes through `data_last` to the selected specialized parser.
- `rtl/itch/itch_parser_{add,execute,cancel,delete,replace}.sv` decode the
  supported order-book messages.
- `rtl/itch_pipeline.sv` connects the normalized parser output to the
  asynchronous event FIFO.


Using [NASDAQ TotalView-ITCH 5.0](https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification_5.0.pdf) for itch parser.
