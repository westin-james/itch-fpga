`timescale 1ns/1ps

module itch_parser_execute (
    input logic clk,
    input logic reset,

    input logic [7:0]   data_in,
    input logic         data_valid,
    input logic         data_start,
    input logic         data_last,
    input logic [15:0]  message_length,

    output logic event_valid,
    output itch_event_pkg::itch_event_t event_data,
    output logic parse_error
);

    import itch_event_pkg::*;

    logic [7:0] message_type;
    logic [5:0] byte_index;
    logic [15:0] captured_length;
    logic parsing_message;

    always_ff @(posedge clk) begin
        if (reset) begin
            message_type        <= 8'b0;
            byte_index          <= 6'b0;
            captured_length     <= 16'b0;
            parsing_message     <= 1'b0;

            event_valid         <= 1'b0;
            parse_error         <= 1'b0;
            event_data          <= '0;
        end else begin
            event_valid <= 1'b0;
            parse_error <= 1'b0;

            if (data_valid) begin
                if (data_start) begin
                    message_type    <= data_in;
                    byte_index      <= 6'd1;
                    captured_length <= message_length;
                    parsing_message <= 1'b1;

                    event_data <= '0;

                    if (data_in != MSG_ORDER_EXECUTED && data_in != MSG_ORDER_EXECUTED_PRICE) begin
                        parsing_message <= 1'b0;
                        parse_error <= 1'b1;
                    end

                end else if (parsing_message) begin
                    case (byte_index)
                        // Bytes 1-2: Stock Locate
                        6'd1, 6'd2: event_data.stock_locate <= {event_data.stock_locate[7:0], data_in};

                        // Bytes 3-4: Tracking Number
                        6'd3, 6'd4: event_data.tracking_number <= {event_data.tracking_number[7:0], data_in};
                        
                        // Bytes 5-10: Timestamp
                        6'd5, 6'd6, 6'd7, 6'd8, 6'd9, 6'd10:
                            event_data.timestamp <= {event_data.timestamp[39:0], data_in};

                        // Bytes 11-18: Order Reference Number
                        6'd11, 6'd12, 6'd13, 6'd14, 6'd15, 6'd16, 6'd17, 6'd18: 
                            event_data.order_reference <= {event_data.order_reference[55:0], data_in};

                        // Bytes 19-22: Executed Shares
                        6'd19, 6'd20, 6'd21, 6'd22:
                            event_data.shares <= {event_data.shares[23:0], data_in};

                        // Bytes 23-30: Match Number
                        6'd23, 6'd24, 6'd25, 6'd26, 6'd27, 6'd28, 6'd29, 6'd30: 
                            event_data.match_number <= {event_data.match_number[55:0], data_in};

                        // Byte 31: Printable, C Only
                        6'd31: event_data.printable <= data_in;

                        // Bytes 32-35: Execution Price, C Only
                        6'd32, 6'd33, 6'd34, 6'd35:
                            event_data.price <= {event_data.price[23:0], data_in};

                        default: begin
                        end
                    endcase

                    if (data_last) begin
                        parsing_message <= 1'b0;
                        if (message_type == MSG_ORDER_EXECUTED 
                        && captured_length == LEN_ORDER_EXECUTED 
                        && byte_index == LEN_ORDER_EXECUTED - 1) begin
                            event_valid <= 1'b1;
                            event_data.event_type <= MSG_ORDER_EXECUTED;

                        end else if (message_type == MSG_ORDER_EXECUTED_PRICE
                        && captured_length == LEN_ORDER_EXECUTED_PRICE
                        && byte_index == LEN_ORDER_EXECUTED_PRICE - 1) begin
                            event_valid <= 1'b1;
                            event_data.event_type <= MSG_ORDER_EXECUTED_PRICE;
                            event_data.has_execution_price <= 1'b1;

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
