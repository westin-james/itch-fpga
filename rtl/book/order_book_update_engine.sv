module order_book_update_engine (
    input logic clk,
    input logic reset,

    // Event input
    input order_book_pkg::book_event_t event_in,
    input logic event_valid,
    output logic event_ready,

    // Order lookup request
    output logic order_lookup_valid,
    output logic [63:0] order_lookup_id,

    // Order lookup response
    input logic order_lookup_response_valid,
    input logic order_lookup_hit,
    input order_book_pkg::order_entry_t order_lookup_entry,

    // Order insert
    output logic order_insert_valid,
    output order_book_pkg::order_entry_t order_insert_entry,

    // Order quantity update
    output logic order_update_valid,
    output logic [63:0] order_update_id,
    output logic [31:0] order_update_quantity,

    // Order deletion
    output logic order_delete_valid,
    output logic [63:0] order_delete_id,

    // Price-level update
    output logic price_update_valid,
    output logic price_update_side,
    output logic [31:0] price_update_price,
    output logic signed [32:0] price_update_quantity_delta
);