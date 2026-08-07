`timescale 1ns/1ps

module itch_parser_add_tb;

    import itch_event_pkg::*;

    localparam time CLOCK_PERIOD = 10ns;

    localparam logic [15:0] TEST_STOCK_LOCATE    = 16'h1234;
    localparam logic [15:0] TEST_TRACKING_NUMBER = 16'h5678;
    localparam logic [47:0] TEST_TIMESTAMP       = 48'h010203040506;
    localparam logic [63:0] TEST_ORDER_REFERENCE = 64'h1122334455667788;
    localparam logic [7:0]  TEST_SIDE            = "B";
    localparam logic [31:0] TEST_SHARES          = 32'd500;
    localparam logic [63:0] TEST_STOCK           = "AAPL    ";
    localparam logic [31:0] TEST_PRICE           = 32'd1_875_000;
    localparam logic [31:0] TEST_MPID            = "ABCD";

    logic clk;
    logic reset;

    logic [7:0]  data_in;
    logic        data_valid;
    logic        data_start;
    logic        data_last;
    logic [15:0] message_length;

    logic        event_valid;
    itch_event_t event_data;
    logic        parse_error;

    integer errors;

    itch_parser_add dut (
        .clk              (clk),
        .reset            (reset),
        .data_in          (data_in),
        .data_valid       (data_valid),
        .data_start       (data_start),
        .data_last        (data_last),
        .message_length   (message_length),
        .event_valid      (event_valid),
        .event_data       (event_data),
        .parse_error      (parse_error)
    );

    initial clk = 1'b0;
    always #(CLOCK_PERIOD / 2) clk = ~clk;

    task automatic drive_byte (
        input logic [7:0] value,
        input logic       first,
        input logic       last
    );
        begin
            @(negedge clk);
            data_in    = value;
            data_valid = 1'b1;
            data_start = first;
            data_last  = last;
        end
    endtask

    task automatic idle_bus;
        begin
            @(negedge clk);
            data_in    = 8'b0;
            data_valid = 1'b0;
            data_start = 1'b0;
            data_last  = 1'b0;
        end
    endtask

    task automatic drive_u16(input logic [15:0] value);
        begin
            drive_byte(value[15:8], 1'b0, 1'b0);
            drive_byte(value[7:0],  1'b0, 1'b0);
        end
    endtask

    task automatic drive_u32 (
        input logic [31:0] value,
        input logic        last_on_final_byte
    );
        begin
            drive_byte(value[31:24], 1'b0, 1'b0);
            drive_byte(value[23:16], 1'b0, 1'b0);
            drive_byte(value[15:8],  1'b0, 1'b0);
            drive_byte(value[7:0],   1'b0, last_on_final_byte);
        end
    endtask

    task automatic drive_u48(input logic [47:0] value);
        begin
            drive_byte(value[47:40], 1'b0, 1'b0);
            drive_byte(value[39:32], 1'b0, 1'b0);
            drive_byte(value[31:24], 1'b0, 1'b0);
            drive_byte(value[23:16], 1'b0, 1'b0);
            drive_byte(value[15:8],  1'b0, 1'b0);
            drive_byte(value[7:0],   1'b0, 1'b0);
        end
    endtask

    task automatic drive_u64(input logic [63:0] value);
        begin
            drive_byte(value[63:56], 1'b0, 1'b0);
            drive_byte(value[55:48], 1'b0, 1'b0);
            drive_byte(value[47:40], 1'b0, 1'b0);
            drive_byte(value[39:32], 1'b0, 1'b0);
            drive_byte(value[31:24], 1'b0, 1'b0);
            drive_byte(value[23:16], 1'b0, 1'b0);
            drive_byte(value[15:8],  1'b0, 1'b0);
            drive_byte(value[7:0],   1'b0, 1'b0);
        end
    endtask

    task automatic send_add_message (
        input logic [7:0]  message_type,
        input logic [15:0] supplied_length
    );
        begin
            message_length = supplied_length;

            drive_byte(message_type, 1'b1, 1'b0);
            drive_u16(TEST_STOCK_LOCATE);
            drive_u16(TEST_TRACKING_NUMBER);
            drive_u48(TEST_TIMESTAMP);
            drive_u64(TEST_ORDER_REFERENCE);
            drive_byte(TEST_SIDE, 1'b0, 1'b0);
            drive_u32(TEST_SHARES, 1'b0);
            drive_u64(TEST_STOCK);

            if (message_type == MSG_ORDER_ADD) begin
                drive_u32(TEST_PRICE, 1'b1);
            end else begin
                drive_u32(TEST_PRICE, 1'b0);
                drive_u32(TEST_MPID, 1'b1);
            end

            // The final byte was driven on a falling edge. The DUT consumes it
            // and updates its outputs on this rising edge.
            @(posedge clk);
            #1;
        end
    endtask

    task automatic check_value (
        input string        name,
        input logic [127:0] actual,
        input logic [127:0] expected
    );
        begin
            if (actual !== expected) begin
                $error("%s: expected 0x%0h, got 0x%0h", name, expected, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: %s = 0x%0h", name, actual);
            end
        end
    endtask

    task automatic check_common_fields;
        begin
            check_value("stock_locate",    event_data.stock_locate,    TEST_STOCK_LOCATE);
            check_value("tracking_number", event_data.tracking_number, TEST_TRACKING_NUMBER);
            check_value("timestamp",       event_data.timestamp,       TEST_TIMESTAMP);
            check_value("order_reference", event_data.order_reference, TEST_ORDER_REFERENCE);
            check_value("side",            event_data.side,            TEST_SIDE);
            check_value("shares",          event_data.shares,          TEST_SHARES);
            check_value("stock",           event_data.stock,           TEST_STOCK);
            check_value("price",           event_data.price,           TEST_PRICE);
        end
    endtask

    initial begin
        string vcd_path;

        if (!$value$plusargs("VCD=%s", vcd_path)) begin
            vcd_path = "build/waves/itch/itch_parser_add_tb.vcd";
        end

        $dumpfile(vcd_path);
        $dumpvars(0, itch_parser_add_tb);

        errors         = 0;
        reset          = 1'b1;
        data_in        = 8'b0;
        data_valid     = 1'b0;
        data_start     = 1'b0;
        data_last      = 1'b0;
        message_length = 16'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        $display("\nTEST 1: valid 36-byte Add Order (A)");
        send_add_message(MSG_ORDER_ADD, LEN_ORDER_ADD);
        check_value("event_valid", event_valid, 1'b1);
        check_value("event_type", event_data.event_type, MSG_ORDER_ADD);
        check_value("parse_error",     parse_error,     1'b0);
        check_common_fields();
        check_value("has_mpid", event_data.has_mpid, 1'b0);
        check_value("mpid",     event_data.mpid,     32'b0);
        idle_bus();

        $display("\nTEST 2: valid 40-byte Add Order with MPID (F)");
        send_add_message(MSG_ORDER_ADD_MPID, LEN_ORDER_ADD_MPID);
        check_value("event_valid", event_valid, 1'b1);
        check_value("event_type", event_data.event_type, MSG_ORDER_ADD_MPID);
        check_value("parse_error",     parse_error,     1'b0);
        check_common_fields();
        check_value("has_mpid", event_data.has_mpid, 1'b1);
        check_value("mpid",     event_data.mpid,     TEST_MPID);
        idle_bus();

        $display("\nTEST 3: A message with incorrect MoldUDP64 length");
        send_add_message(MSG_ORDER_ADD, LEN_ORDER_ADD - 1);
        check_value("event_valid", event_valid, 1'b0);
        check_value("parse_error",     parse_error,     1'b1);
        idle_bus();

        repeat (2) @(posedge clk);

        if (errors == 0) begin
            $display("\nALL itch_parser_add TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "\nitch_parser_add TESTS FAILED: %0d error(s)", errors);
        end
    end

endmodule
