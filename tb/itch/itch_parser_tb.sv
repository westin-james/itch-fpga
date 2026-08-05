`timescale 1ns/1ps

module itch_parser_tb;

    `include "itch_defs.svh"

    localparam time CLOCK_PERIOD = 10ns;

    localparam logic [15:0] TEST_STOCK_LOCATE    = 16'hCAFE;
    localparam logic [15:0] TEST_TRACKING_NUMBER = 16'h1020;
    localparam logic [47:0] TEST_TIMESTAMP       = 48'h0A0B0C0D0E0F;
    localparam logic [63:0] TEST_ORDER_REFERENCE = 64'h0102030405060708;
    localparam logic [7:0]  TEST_SIDE            = "S";
    localparam logic [31:0] TEST_SHARES          = 32'd250;
    localparam logic [63:0] TEST_STOCK           = "MSFT    ";
    localparam logic [31:0] TEST_PRICE           = 32'd4_125_000;
    localparam logic [31:0] TEST_MPID            = "TEST";

    logic clk;
    logic reset;

    logic [7:0]  data_in;
    logic        data_valid;
    logic        data_start;
    logic        data_last;
    logic [15:0] message_length;

    logic        add_order_valid;
    logic        unsupported_message;
    logic        parse_error;
    logic [15:0] stock_locate;
    logic [15:0] tracking_number;
    logic [47:0] timestamp;
    logic [63:0] order_reference;
    logic [7:0]  side;
    logic [31:0] shares;
    logic [63:0] stock;
    logic [31:0] price;
    logic        has_mpid;
    logic [31:0] mpid;

    integer errors;
    integer i;

    itch_parser dut (
        .clk                 (clk),
        .reset               (reset),
        .data_in             (data_in),
        .data_valid          (data_valid),
        .data_start          (data_start),
        .data_last           (data_last),
        .message_length      (message_length),
        .add_order_valid     (add_order_valid),
        .unsupported_message (unsupported_message),
        .parse_error         (parse_error),
        .stock_locate        (stock_locate),
        .tracking_number     (tracking_number),
        .timestamp           (timestamp),
        .order_reference     (order_reference),
        .side                (side),
        .shares              (shares),
        .stock               (stock),
        .price               (price),
        .has_mpid            (has_mpid),
        .mpid                (mpid)
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

    task automatic send_add_message(input logic [7:0] message_type);
        begin
            if (message_type == MSG_ORDER_ADD)
                message_length = LEN_ORDER_ADD;
            else
                message_length = LEN_ORDER_ADD_MPID;

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

            @(posedge clk);
            #1;
        end
    endtask

    task automatic send_unsupported_system_event;
        begin
            message_length = LEN_SYSTEM_EVENT;
            drive_byte(MSG_SYSTEM_EVENT, 1'b1, 1'b0);

            // A System Event is 12 bytes total. The dispatcher currently does
            // not decode it; it only needs to consume the remaining 11 bytes.
            for (i = 1; i < LEN_SYSTEM_EVENT; i = i + 1) begin
                drive_byte(i[7:0], 1'b0, i == LEN_SYSTEM_EVENT - 1);
            end

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

    task automatic check_add_fields;
        begin
            check_value("stock_locate",    stock_locate,    TEST_STOCK_LOCATE);
            check_value("tracking_number", tracking_number, TEST_TRACKING_NUMBER);
            check_value("timestamp",       timestamp,       TEST_TIMESTAMP);
            check_value("order_reference", order_reference, TEST_ORDER_REFERENCE);
            check_value("side",            side,            TEST_SIDE);
            check_value("shares",          shares,          TEST_SHARES);
            check_value("stock",           stock,           TEST_STOCK);
            check_value("price",           price,           TEST_PRICE);
        end
    endtask

    initial begin
        string vcd_path;

        if (!$value$plusargs("VCD=%s", vcd_path)) begin
            vcd_path = "build/waves/itch/itch_parser_tb.vcd";
        end

        $dumpfile(vcd_path);
        $dumpvars(0, itch_parser_tb);

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

        $display("\nTEST 1: dispatcher routes A to itch_parser_add");
        send_add_message(MSG_ORDER_ADD);
        check_value("add_order_valid",     add_order_valid,     1'b1);
        check_value("unsupported_message", unsupported_message, 1'b0);
        check_value("parse_error",         parse_error,         1'b0);
        check_add_fields();
        check_value("has_mpid", has_mpid, 1'b0);
        idle_bus();

        $display("\nTEST 2: dispatcher safely consumes unsupported S message");
        send_unsupported_system_event();
        check_value("add_order_valid",     add_order_valid,     1'b0);
        check_value("unsupported_message", unsupported_message, 1'b1);
        check_value("parse_error",         parse_error,         1'b0);
        idle_bus();

        $display("\nTEST 3: dispatcher returns to ADD route after unsupported message");
        send_add_message(MSG_ORDER_ADD_MPID);
        check_value("add_order_valid",     add_order_valid,     1'b1);
        check_value("unsupported_message", unsupported_message, 1'b0);
        check_value("parse_error",         parse_error,         1'b0);
        check_add_fields();
        check_value("has_mpid", has_mpid, 1'b1);
        check_value("mpid",     mpid,     TEST_MPID);
        idle_bus();

        $display("\nTEST 4: byte arriving without data_start produces router error");
        message_length = 16'd1;
        drive_byte(8'hAA, 1'b0, 1'b1);
        @(posedge clk);
        #1;
        check_value("add_order_valid",     add_order_valid,     1'b0);
        check_value("unsupported_message", unsupported_message, 1'b0);
        check_value("parse_error",         parse_error,         1'b1);
        idle_bus();

        repeat (2) @(posedge clk);

        if (errors == 0) begin
            $display("\nALL itch_parser TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "\nitch_parser TESTS FAILED: %0d error(s)", errors);
        end
    end

endmodule
