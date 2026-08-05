module itch_parser (
    input logic clk,
    input logic reset,

    input logic [7:0]   data_in,
    input logic         data_valid,
    input logic         data_start,
    input logic         data_last,
    input logic [15:0]  message_length,

    output logic add_order_valid,
    output logic unsupported_message,
    output logic parse_error,

    output logic [15:0] stock_locate,
    output logic [15:0] tracking_number,
    output logic [47:0] timestamp,
    output logic [63:0] order_reference,
    output logic [7:0]  side,
    output logic [31:0] shares,
    output logic [63:0] stock,
    output logic [31:0] price,
    output logic        has_mpid,
    output logic [31:0] mpid
);

    `include "itch_defs.svh"

    localparam logic [1:0] ROUTE_NONE        = 2'd0;
    localparam logic [1:0] ROUTE_ADD         = 2'd1;
    localparam logic [1:0] ROUTE_UNSUPPORTED = 2'd2;

    logic [1:0] active_route;

    logic router_error;
    logic add_parse_error;

    logic [7:0] add_data;
    logic add_valid;
    logic add_start;
    logic add_last;

    assign parse_error = router_error | add_parse_error;

    always_comb begin
        add_data = data_in;
        add_valid = 1'b0;
        add_start = 1'b0;
        add_last = 1'b0;

        if (data_valid) begin
            if (data_start) begin
                if (data_in == MSG_ORDER_ADD || data_in == MSG_ORDER_ADD_MPID) begin
                    add_valid = 1'b1;
                    add_start = 1'b1;
                    add_last = data_last;
                end
            end else if (active_route == ROUTE_ADD) begin
                add_valid = 1'b1;
                add_start = 1'b0;
                add_last = data_last;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            active_route <= ROUTE_NONE;
            unsupported_message <= 1'b0;
            router_error <= 1'b0;
        end else begin
            unsupported_message <= 1'b0;
            router_error <= 1'b0;

            if (data_valid) begin 
                if (data_start) begin
                    if (active_route != ROUTE_NONE) router_error <= 1'b1;
                    case(data_in)
                        MSG_ORDER_ADD, MSG_ORDER_ADD_MPID: begin
                            if (data_last) active_route <= ROUTE_NONE;
                            else active_route <= ROUTE_ADD;
                        end

                        // TODO more routes here

                        // Unsupported message path 
                        default: begin
                            if (data_last) begin
                                active_route <= ROUTE_NONE;
                                unsupported_message <= 1'b1;
                            end else begin
                                active_route <= ROUTE_UNSUPPORTED;
                            end
                        end
                    endcase
                end else begin
                    if (active_route == ROUTE_NONE) router_error <= 1'b1;
                    if (data_last) begin
                        if (active_route == ROUTE_UNSUPPORTED) unsupported_message <= 1'b1;
                        active_route <= ROUTE_NONE;
                    end
                end
            end
        end
    end
    
    itch_parser_add add_parser (
        .clk(clk),
        .reset(reset),

        .data_in(add_data),
        .data_valid(add_valid),
        .data_start(add_start),
        .data_last(add_last),
        .message_length(message_length),

        .add_order_valid(add_order_valid),
        .parse_error(add_parse_error),

        .stock_locate(stock_locate),
        .tracking_number(tracking_number),
        .timestamp(timestamp),
        .order_reference(order_reference),
        .side(side),
        .shares(shares),
        .stock(stock),
        .price(price),
        .has_mpid(has_mpid),
        .mpid(mpid)
    );

endmodule

/* 
    Just checking for add orders for now
    Expecting MoldUDP64 decoder to provide the following inputs:
    message length from 2-byte length before ITCH
    1 ITCH packet at a time
*/