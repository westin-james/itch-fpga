module bbo_tracker (
    input logic clk,
    input logic reset,

    // Notification that a price level changed
    input logic level_update_valid,
    input logic level_side,
    input logic [31:0] level_price,
    input logic [31:0] level_quantity,

    input logic level_became_empty,
    input logic level_became_nonempty,

    // Best bid
    output logic best_bid_valid,
    output logic [31:0] best_bid_price,
    output logic [31:0] best_bid_quantity,

    // Best ask
    output logic best_ask_valid,
    output logic [31:0] best_ask_price,
    output logic [31:0] best_ask_quantity,

    output logic bbo_update_valid
);