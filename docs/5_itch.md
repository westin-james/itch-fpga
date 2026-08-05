# ITCH parser
input: raw ITCH message
output: decoded market event

## TODO


## File structure:
rtl/itch/
 - itch_defs.svh for message type value constants
 - itch_parser.sv for redirecting itch packet (dispatcher)
    - looks at first byte, selects parser, remembers and routes every byte until data_last
 - itch_parser_add.sv 


Using [NASDAQ TotalView-ITCH 5.0](https://www.nasdaqtrader.com/content/technicalsupport/specifications/dataproducts/NQTVITCHSpecification_5.0.pdf) for itch parser.