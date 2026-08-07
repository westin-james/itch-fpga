`timescale 1ns/1ps

module itch_pipeline #(
    parameter int unsigned EVENT_FIFO_DEPTH =
        sys_defs_pkg::EVENT_FIFO_DEPTH
) (
    input logic parser_clk,
    input logic parser_reset,

    input logic [7:0]  data_in,
    input logic        data_valid,
    input logic        data_start,
    input logic        data_last,
    input logic [15:0] message_length,

    input logic event_clk,
    input logic event_reset,
    output logic event_valid,
    input logic event_ready,
    output itch_event_pkg::itch_event_t event_data,

    output logic unsupported_message,
    output logic parse_error,
    output logic fifo_write_ready,
    output logic fifo_overflow
);

    logic parser_event_valid;
    itch_event_pkg::itch_event_t parser_event_data;

    itch_parser parser (
        .clk                 (parser_clk),
        .reset               (parser_reset),
        .data_in             (data_in),
        .data_valid          (data_valid),
        .data_start          (data_start),
        .data_last           (data_last),
        .message_length      (message_length),
        .event_valid         (parser_event_valid),
        .event_data          (parser_event_data),
        .unsupported_message (unsupported_message),
        .parse_error         (parse_error)
    );

    event_fifo #(
        .DEPTH(EVENT_FIFO_DEPTH)
    ) event_buffer (
        .wr_clk       (parser_clk),
        .wr_reset     (parser_reset),
        .wr_valid     (parser_event_valid),
        .wr_ready     (fifo_write_ready),
        .wr_data      (parser_event_data),
        .wr_overflow  (fifo_overflow),
        .rd_clk       (event_clk),
        .rd_reset     (event_reset),
        .rd_valid     (event_valid),
        .rd_ready     (event_ready),
        .rd_data      (event_data)
    );

endmodule
