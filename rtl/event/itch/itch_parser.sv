`timescale 1ns/1ps

module itch_parser (
    input logic clk,
    input logic reset,

    input logic [7:0]   data_in,
    input logic         data_valid,
    input logic         data_start,
    input logic         data_last,
    input logic [15:0]  message_length,

    // normalized event interface
    output logic event_valid,
    output itch_event_pkg::itch_event_t event_data,
    output logic unsupported_message,
    output logic parse_error
);

    import itch_event_pkg::*;

    localparam logic [2:0] ROUTE_NONE        = 3'd0;
    localparam logic [2:0] ROUTE_ADD         = 3'd1;
    localparam logic [2:0] ROUTE_EXECUTE     = 3'd2;
    localparam logic [2:0] ROUTE_CANCEL      = 3'd3;
    localparam logic [2:0] ROUTE_DELETE      = 3'd4;
    localparam logic [2:0] ROUTE_REPLACE     = 3'd5;
    localparam logic [2:0] ROUTE_UNSUPPORTED = 3'd6;

    logic [2:0] active_route;
    logic router_error;

    logic add_valid, add_start, add_last, add_parse_error, add_event_valid;
    logic execute_valid, execute_start, execute_last, execute_parse_error, execute_event_valid;
    logic cancel_valid, cancel_start, cancel_last, cancel_parse_error, cancel_event_valid;
    logic delete_valid, delete_start, delete_last, delete_parse_error, delete_event_valid;
    logic replace_valid, replace_start, replace_last, replace_parse_error, replace_event_valid;

    itch_event_t add_event_data;
    itch_event_t execute_event_data;
    itch_event_t cancel_event_data;
    itch_event_t delete_event_data;
    itch_event_t replace_event_data;

    assign parse_error = router_error | add_parse_error | execute_parse_error |
                         cancel_parse_error | delete_parse_error | replace_parse_error;

    // route datastream to specialized parser
    always_comb begin
        add_valid = 1'b0; add_start = 1'b0; add_last = 1'b0;
        execute_valid = 1'b0; execute_start = 1'b0; execute_last = 1'b0;
        cancel_valid = 1'b0; cancel_start = 1'b0; cancel_last = 1'b0;
        delete_valid = 1'b0; delete_start = 1'b0; delete_last = 1'b0;
        replace_valid = 1'b0; replace_start = 1'b0; replace_last = 1'b0;

        if (data_valid) begin
            if (data_start) begin
                case (data_in)
                    MSG_ORDER_ADD, MSG_ORDER_ADD_MPID: begin
                        add_valid = 1'b1; add_start = 1'b1; add_last = data_last;
                    end
                    MSG_ORDER_EXECUTED, MSG_ORDER_EXECUTED_PRICE: begin
                        execute_valid = 1'b1; execute_start = 1'b1; execute_last = data_last;
                    end
                    MSG_ORDER_CANCEL: begin
                        cancel_valid = 1'b1; cancel_start = 1'b1; cancel_last = data_last;
                    end
                    MSG_ORDER_DELETE: begin
                        delete_valid = 1'b1; delete_start = 1'b1; delete_last = data_last;
                    end
                    MSG_ORDER_REPLACE: begin
                        replace_valid = 1'b1; replace_start = 1'b1; replace_last = data_last;
                    end
                    default: begin end
                endcase
            end else begin
                case (active_route)
                    ROUTE_ADD: begin add_valid = 1'b1; add_last = data_last; end
                    ROUTE_EXECUTE: begin execute_valid = 1'b1; execute_last = data_last; end
                    ROUTE_CANCEL: begin cancel_valid = 1'b1; cancel_last = data_last; end
                    ROUTE_DELETE: begin delete_valid = 1'b1; delete_last = data_last; end
                    ROUTE_REPLACE: begin replace_valid = 1'b1; replace_last = data_last; end
                    default: begin end
                endcase
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
                    if (active_route != ROUTE_NONE)
                        router_error <= 1'b1;
                    case (data_in)
                        MSG_ORDER_ADD, MSG_ORDER_ADD_MPID:
                            active_route <= data_last ? ROUTE_NONE : ROUTE_ADD;
                        MSG_ORDER_EXECUTED, MSG_ORDER_EXECUTED_PRICE:
                            active_route <= data_last ? ROUTE_NONE : ROUTE_EXECUTE;
                        MSG_ORDER_CANCEL:
                            active_route <= data_last ? ROUTE_NONE : ROUTE_CANCEL;
                        MSG_ORDER_DELETE:
                            active_route <= data_last ? ROUTE_NONE : ROUTE_DELETE;
                        MSG_ORDER_REPLACE:
                            active_route <= data_last ? ROUTE_NONE : ROUTE_REPLACE;
                        default: begin
                            active_route <= data_last ? ROUTE_NONE : ROUTE_UNSUPPORTED;
                            if (data_last)
                                unsupported_message <= 1'b1;
                        end
                    endcase
                end else begin
                    if (active_route == ROUTE_NONE)
                        router_error <= 1'b1;
                    if (data_last) begin
                        if (active_route == ROUTE_UNSUPPORTED)
                            unsupported_message <= 1'b1;
                        active_route <= ROUTE_NONE;
                    end
                end
            end
        end
    end

    // multiplex specialized parsers
    always_comb begin
        event_valid = 1'b0;
        event_data = '0;

        if (add_event_valid) begin
            event_valid = 1'b1;
            event_data = add_event_data;
        end else if (execute_event_valid) begin
            event_valid = 1'b1;
            event_data = execute_event_data;
        end else if (cancel_event_valid) begin
            event_valid = 1'b1;
            event_data = cancel_event_data;
        end else if (delete_event_valid) begin
            event_valid = 1'b1;
            event_data = delete_event_data;
        end else if (replace_event_valid) begin
            event_valid = 1'b1;
            event_data = replace_event_data;
        end
    end

    itch_parser_add add_parser (
        .clk(clk), .reset(reset), .data_in(data_in), .data_valid(add_valid),
        .data_start(add_start), .data_last(add_last), .message_length(message_length),
        .event_valid(add_event_valid), .event_data(add_event_data),
        .parse_error(add_parse_error)
    );

    itch_parser_execute execute_parser (
        .clk(clk), .reset(reset), .data_in(data_in), .data_valid(execute_valid),
        .data_start(execute_start), .data_last(execute_last), .message_length(message_length),
        .event_valid(execute_event_valid), .event_data(execute_event_data),
        .parse_error(execute_parse_error)
    );

    itch_parser_cancel cancel_parser (
        .clk(clk), .reset(reset), .data_in(data_in), .data_valid(cancel_valid),
        .data_start(cancel_start), .data_last(cancel_last), .message_length(message_length),
        .event_valid(cancel_event_valid), .event_data(cancel_event_data),
        .parse_error(cancel_parse_error)
    );

    itch_parser_delete delete_parser (
        .clk(clk), .reset(reset), .data_in(data_in), .data_valid(delete_valid),
        .data_start(delete_start), .data_last(delete_last), .message_length(message_length),
        .event_valid(delete_event_valid), .event_data(delete_event_data),
        .parse_error(delete_parse_error)
    );

    itch_parser_replace replace_parser (
        .clk(clk), .reset(reset), .data_in(data_in), .data_valid(replace_valid),
        .data_start(replace_start), .data_last(replace_last), .message_length(message_length),
        .event_valid(replace_event_valid), .event_data(replace_event_data),
        .parse_error(replace_parse_error)
    );

endmodule
