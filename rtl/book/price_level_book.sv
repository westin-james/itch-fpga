module price_level_book (
    input logic clk,
    input logic reset,

    // Price-level modification
    input logic update_valid,
    input logic update_side,
    input logic [31:0] update_price,
    input logic signed [32:0] update_quantity_delta,

    // Updated level result
    output logic level_update_valid,
    output logic level_side,
    output logic [31:0] level_price,
    output logic [31:0] level_quantity,

    // Indicates this level became empty/non-empty
    output logic level_became_empty,
    output logic level_became_nonempty
);