// itch_defs.svh

///////////////////
// Message Types //
///////////////////

// System Event Message
localparam logic [7:0] MSG_SYSTEM_EVENT = "S";

// Stock-Related Messages
localparam logic [7:0] MSG_STOCK_DIRECTORY      = "R";
localparam logic [7:0] MSG_TRADING_ACTION       = "H";
localparam logic [7:0] MSG_REG_SHO_RESTRICTION  = "Y";
localparam logic [7:0] MSG_PARTICIPANT_POSITION = "L";
localparam logic [7:0] MSG_MWCB_DECLINE_LEVEL   = "V";
localparam logic [7:0] MSG_MWCB_STATUS          = "W";
localparam logic [7:0] MSG_IPO_QUOTE_UPDATE     = "K";

// Add Order Messages
localparam logic [7:0] MSG_ORDER_ADD        = "A";
localparam logic [7:0] MSG_ORDER_ADD_MPID   = "F";

// Modify Order Messages
localparam logic [7:0] MSG_ORDER_EXECUTED       = "E";
localparam logic [7:0] MSG_ORDER_EXECUTED_PRICE = "C";
localparam logic [7:0] MSG_ORDER_CANCEL         = "X";
localparam logic [7:0] MSG_ORDER_DELETE         = "D";
localparam logic [7:0] MSG_ORDER_REPLACE        = "U";

// Trade Messages
localparam logic [7:0] MSG_TRADE        = "P";
localparam logic [7:0] MSG_TRADE_CROSS  = "Q";
localparam logic [7:0] MSG_TRADE_BROKEN = "B";

// Net Order Imbalance Indicator
localparam logic [7:0] MSG_NOII = "I";

// Retail Price Improvement Indicator
localparam logic [7:0] MSG_RPII = "N";

// Additional Stock-Related Messages
localparam logic [7:0] MSG_LULD_AUCTION_COLLAR  = "J";
localparam logic [7:0] MSG_OPERATIONAL_HALT     = "h";

// Direct Listing with Capital Raise
localparam logic [7:0] MSG_DLCR_PRICE_DISCOVERY = "O";

/////////////////////
// Message Lengths //
/////////////////////

// System Event Message
localparam int unsigned LEN_SYSTEM_EVENT = 12;

// Stock-Related Messages
localparam int unsigned LEN_STOCK_DIRECTORY      = 39;
localparam int unsigned LEN_TRADING_ACTION       = 25;
localparam int unsigned LEN_REG_SHO_RESTRICTION  = 20;
localparam int unsigned LEN_PARTICIPANT_POSITION = 26;
localparam int unsigned LEN_MWCB_DECLINE_LEVEL   = 35;
localparam int unsigned LEN_MWCB_STATUS          = 12;
localparam int unsigned LEN_IPO_QUOTE_UPDATE     = 28;

// Add Order Messages
localparam int unsigned LEN_ORDER_ADD      = 36;
localparam int unsigned LEN_ORDER_ADD_MPID = 40;

// Modify Order Messages
localparam int unsigned LEN_ORDER_EXECUTED       = 31;
localparam int unsigned LEN_ORDER_EXECUTED_PRICE = 36;
localparam int unsigned LEN_ORDER_CANCEL         = 23;
localparam int unsigned LEN_ORDER_DELETE         = 19;
localparam int unsigned LEN_ORDER_REPLACE        = 35;

// Trade Messages
localparam int unsigned LEN_TRADE        = 44;
localparam int unsigned LEN_TRADE_CROSS  = 40;
localparam int unsigned LEN_TRADE_BROKEN = 19;

// Net Order Imbalance Indicator
localparam int unsigned LEN_NOII = 50;

// Retail Price Improvement Indicator
localparam int unsigned LEN_RPII = 20;

// Additional Stock-Related Messages
localparam int unsigned LEN_LULD_AUCTION_COLLAR = 35;
localparam int unsigned LEN_OPERATIONAL_HALT    = 21;

// Direct Listing with Capital Raise
localparam int unsigned LEN_DLCR_PRICE_DISCOVERY = 48;