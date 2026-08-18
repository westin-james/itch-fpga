module order_lookup (
    input logic clk,
    input logic reset,

    // Lookup request
    input logic lookup_valid,
    input logic [63:0] lookup_order_id,

    // Lookup response
    output logic lookup_response_valid,
    output logic lookup_hit,
    output order_book_pkg::order_entry_t  lookup_entry,

    // Insert new order
    input logic insert_valid,
    input order_book_pkg::order_entry_t  insert_entry,

    // Update remaining quantity
    input logic update_valid,
    input logic [63:0] update_order_id,
    input logic [31:0] update_quantity,

    // Remove order
    input logic delete_valid,
    input logic [63:0] delete_order_id
);