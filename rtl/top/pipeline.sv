`timescale 1ns/1ps

module pipeline #(
    parameter int unsigned EVENT_FIFO_DEPTH =
        sys_defs_pkg::EVENT_FIFO_DEPTH
) (
    input logic parser_clk,
    input logic parser_reset,

    input logic [7:0]  data_in,
    input logic        data_valid,
    input logic        data_start,
    input logic        data_last,
    input logic [47:0] expected_dest_mac,
    input logic [31:0] expected_dest_ip,
    input logic [15:0] expected_dest_port,

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

    logic [7:0] ethernet_data;
    logic ethernet_valid;
    logic ethernet_start;
    logic ethernet_last;

    logic [7:0] ipv4_data;
    logic ipv4_valid;
    logic ipv4_start;
    logic ipv4_last;

    logic [7:0] udp_data;
    logic udp_valid;
    logic udp_start;
    logic udp_last;

    logic [7:0] itch_data;
    logic itch_valid;
    logic itch_start;
    logic itch_last;
    logic [15:0] itch_length;

    logic parser_event_valid;
    itch_event_pkg::itch_event_t parser_event_data;

    ethernet_decoder ethernet (
        .clk                    (parser_clk),
        .reset                  (parser_reset),
        .data_in                (data_in),
        .frame_valid            (data_valid),
        .frame_start            (data_start),
        .frame_last             (data_last),
        .expected_dest_mac      (expected_dest_mac),
        .data_out               (ethernet_data),
        .ethernet_payload_valid (ethernet_valid),
        .ethernet_payload_start (ethernet_start),
        .ethernet_payload_last  (ethernet_last)
    );

    ipv4_decoder ipv4 (
        .clk                    (parser_clk),
        .reset                  (parser_reset),
        .data_in                (ethernet_data),
        .ethernet_payload_valid (ethernet_valid),
        .ethernet_payload_start (ethernet_start),
        .ethernet_payload_last  (ethernet_last),
        .expected_dest_ip       (expected_dest_ip),
        .data_out               (ipv4_data),
        .ipv4_payload_valid     (ipv4_valid),
        .ipv4_payload_start     (ipv4_start),
        .ipv4_payload_last      (ipv4_last)
    );

    udp_decoder udp (
        .clk                (parser_clk),
        .reset              (parser_reset),
        .data_in            (ipv4_data),
        .ipv4_payload_valid (ipv4_valid),
        .ipv4_payload_start (ipv4_start),
        .ipv4_payload_last  (ipv4_last),
        .expected_dest_port (expected_dest_port),
        .data_out           (udp_data),
        .udp_payload_valid  (udp_valid),
        .udp_payload_start  (udp_start),
        .udp_payload_last   (udp_last)
    );

    moldudp64_decoder moldudp64 (
        .clk               (parser_clk),
        .reset             (parser_reset),
        .data_in           (udp_data),
        .udp_payload_valid (udp_valid),
        .udp_payload_start (udp_start),
        .udp_payload_last  (udp_last),
        .data_out          (itch_data),
        .itch_msg_valid    (itch_valid),
        .itch_msg_start    (itch_start),
        .itch_msg_last     (itch_last),
        .itch_msg_length   (itch_length)
    );

    itch_parser parser (
        .clk                 (parser_clk),
        .reset               (parser_reset),
        .data_in             (itch_data),
        .data_valid          (itch_valid),
        .data_start          (itch_start),
        .data_last           (itch_last),
        .message_length      (itch_length),
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
