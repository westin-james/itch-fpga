`timescale 1ns/1ps

package itch_event_pkg;

    // NASDAQ ITCH 5.0 message identifiers
    localparam logic [7:0] MSG_SYSTEM_EVENT         = "S";
    localparam logic [7:0] MSG_STOCK_DIRECTORY      = "R";
    localparam logic [7:0] MSG_TRADING_ACTION       = "H";
    localparam logic [7:0] MSG_REG_SHO_RESTRICTION  = "Y";
    localparam logic [7:0] MSG_PARTICIPANT_POSITION = "L";
    localparam logic [7:0] MSG_MWCB_DECLINE_LEVEL   = "V";
    localparam logic [7:0] MSG_MWCB_STATUS          = "W";
    localparam logic [7:0] MSG_IPO_QUOTE_UPDATE     = "K";
    localparam logic [7:0] MSG_ORDER_ADD             = "A";
    localparam logic [7:0] MSG_ORDER_ADD_MPID        = "F";
    localparam logic [7:0] MSG_ORDER_EXECUTED        = "E";
    localparam logic [7:0] MSG_ORDER_EXECUTED_PRICE  = "C";
    localparam logic [7:0] MSG_ORDER_CANCEL          = "X";
    localparam logic [7:0] MSG_ORDER_DELETE          = "D";
    localparam logic [7:0] MSG_ORDER_REPLACE         = "U";
    localparam logic [7:0] MSG_TRADE                 = "P";
    localparam logic [7:0] MSG_TRADE_CROSS           = "Q";
    localparam logic [7:0] MSG_TRADE_BROKEN          = "B";
    localparam logic [7:0] MSG_NOII                   = "I";
    localparam logic [7:0] MSG_RPII                   = "N";
    localparam logic [7:0] MSG_LULD_AUCTION_COLLAR   = "J";
    localparam logic [7:0] MSG_OPERATIONAL_HALT      = "h";
    localparam logic [7:0] MSG_DLCR_PRICE_DISCOVERY  = "O";

    // message sizes in bytes, including message-type byte
    localparam int unsigned LEN_SYSTEM_EVENT         = 12;
    localparam int unsigned LEN_STOCK_DIRECTORY      = 39;
    localparam int unsigned LEN_TRADING_ACTION       = 25;
    localparam int unsigned LEN_REG_SHO_RESTRICTION  = 20;
    localparam int unsigned LEN_PARTICIPANT_POSITION = 26;
    localparam int unsigned LEN_MWCB_DECLINE_LEVEL   = 35;
    localparam int unsigned LEN_MWCB_STATUS          = 12;
    localparam int unsigned LEN_IPO_QUOTE_UPDATE     = 28;
    localparam int unsigned LEN_ORDER_ADD             = 36;
    localparam int unsigned LEN_ORDER_ADD_MPID        = 40;
    localparam int unsigned LEN_ORDER_EXECUTED        = 31;
    localparam int unsigned LEN_ORDER_EXECUTED_PRICE  = 36;
    localparam int unsigned LEN_ORDER_CANCEL          = 23;
    localparam int unsigned LEN_ORDER_DELETE          = 19;
    localparam int unsigned LEN_ORDER_REPLACE         = 35;
    localparam int unsigned LEN_TRADE                 = 44;
    localparam int unsigned LEN_TRADE_CROSS           = 40;
    localparam int unsigned LEN_TRADE_BROKEN          = 19;
    localparam int unsigned LEN_NOII                   = 50;
    localparam int unsigned LEN_RPII                   = 20;
    localparam int unsigned LEN_LULD_AUCTION_COLLAR   = 35;
    localparam int unsigned LEN_OPERATIONAL_HALT      = 21;
    localparam int unsigned LEN_DLCR_PRICE_DISCOVERY  = 48;

    // itch_parser zeros fields that do not apply to an event before asserting event_valid
    typedef struct packed {
        logic [7:0]  event_type;
        logic [15:0] stock_locate;
        logic [15:0] tracking_number;
        logic [47:0] timestamp;
        logic [63:0] order_reference;
        logic [63:0] new_order_reference;
        logic [7:0]  side;
        logic [31:0] shares;
        logic [63:0] stock;
        logic [31:0] price;
        logic [63:0] match_number;
        logic        has_mpid;
        logic [31:0] mpid;
        logic        has_execution_price;
        logic [7:0]  printable;
    } itch_event_t;

    localparam int unsigned ITCH_EVENT_WIDTH = $bits(itch_event_t);

endpackage
