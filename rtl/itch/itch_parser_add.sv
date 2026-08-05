module itch_parser_add (
    input logic clk,
    input logic reset,

    input logic [7:0]   data_in,
    input logic         data_valid,
    input logic         data_start,
    input logic         data_last,
    input logic [15:0]  message_length,

    output logic add_order_valid,
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

    logic [7:0] message_type;
    logic [5:0] byte_index;
    logic [15:0] captured_length;
    logic parsing_message;

    always_ff @(posedge clk) begin
        if (reset) begin
            message_type    <= 8'b0;
            byte_index      <= 6'b0;
            captured_length <= 16'b0;
            parsing_message <= 1'b0;

            add_order_valid <= 1'b0;
            parse_error     <= 1'b0;

            stock_locate    <= 16'b0;
            tracking_number <= 16'b0;
            timestamp       <= 48'b0;
            order_reference <= 64'b0;
            side            <= 8'b0;
            shares          <= 32'b0;
            stock           <= 64'b0;
            price           <= 32'b0;
            has_mpid        <= 1'b0;
            mpid            <= 32'b0;
        end else begin
            add_order_valid <= 1'b0;
            parse_error     <= 1'b0;

            if (data_valid) begin
                if (data_start) begin
                    message_type <= data_in;
                    byte_index <= 6'd1;
                    captured_length <= message_length;
                    parsing_message <= 1'b1;

                    stock_locate    <= 16'b0;
                    tracking_number <= 16'b0;
                    timestamp       <= 48'b0;
                    order_reference <= 64'b0;
                    side            <= 8'b0;
                    shares          <= 32'b0;
                    stock           <= 64'b0;
                    price           <= 32'b0;
                    has_mpid        <= 1'b0;
                    mpid            <= 32'b0;

                    has_mpid <= (data_in == MSG_ORDER_ADD_MPID);

                    if (data_in != MSG_ORDER_ADD && data_in != MSG_ORDER_ADD_MPID) begin // Must be an add order
                        parsing_message <= 1'b0;
                        parse_error <= 1'b1;
                    end

                end else if (parsing_message) begin
                    case (byte_index)
                        6'd1, 6'd2: stock_locate <= {stock_locate[7:0], data_in};
                        6'd3, 6'd4: tracking_number <= {tracking_number[7:0], data_in};
                        6'd5, 6'd6, 6'd7, 6'd8, 6'd9, 6'd10: timestamp <= {timestamp[39:0], data_in};
                        6'd11, 6'd12, 6'd13, 6'd14, 6'd15, 6'd16, 6'd17, 6'd18: 
                            order_reference <= {order_reference[55:0], data_in};
                        6'd19: side <= data_in;
                        6'd20, 6'd21, 6'd22, 6'd23: shares <= {shares[23:0], data_in};
                        6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29, 6'd30, 6'd31: stock <= {stock[55:0], data_in};
                        6'd32, 6'd33, 6'd34, 6'd35: price <= {price[23:0], data_in};
                        // Only in MPID attributed orders
                        6'd36, 6'd37, 6'd38, 6'd39: mpid <= {mpid[23:0], data_in};
                        default: begin
                        end
                    endcase

                    if (data_last) begin
                        parsing_message <= 1'b0;
                        if (message_type == MSG_ORDER_ADD 
                        && captured_length == LEN_ORDER_ADD 
                        && byte_index == LEN_ORDER_ADD - 1) begin
                            add_order_valid <= 1'b1;
                        end else if (message_type == MSG_ORDER_ADD_MPID
                        && captured_length == LEN_ORDER_ADD_MPID
                        && byte_index == LEN_ORDER_ADD_MPID - 1) begin
                            add_order_valid <= 1'b1;
                        end else begin
                            parse_error <= 1'b1;
                        end
                    end else begin
                        byte_index <= byte_index + 1'b1;
                    end
                end else begin
                    parse_error <= 1'b1;
                end
            end
        end
    end

endmodule

/* 
    Just checking for add orders for now
    Expecting MoldUDP64 decoder to provide the following inputs:
    message length from 2-byte length before ITCH
    1 ITCH packet at a time
*/
