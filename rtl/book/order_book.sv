module order_book (
    input logic clk,
    input logic reset,

    // Normalized ITCH event input
    input order_book_pkg::book_event_t event_in,
    input logic event_valid,
    output logic event_ready,

    // Current best bid
    output logic best_bid_valid,
    output logic [31:0] best_bid_price,
    output logic [31:0] best_bid_quantity,

    // Current best ask
    output logic best_ask_valid,
    output logic [31:0] best_ask_price,
    output logic [31:0] best_ask_quantity,

    // Indicates that visible book state changed
    output logic book_update_valid
);