`timescale 1ns/1ps

module itch_parser_tb;

    import itch_event_pkg::*;

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
    localparam logic [63:0] TEST_NEW_REFERENCE   = 64'h8877665544332211;
    localparam logic [63:0] TEST_MATCH_NUMBER    = 64'hA1A2A3A4A5A6A7A8;
    localparam logic [31:0] TEST_EXEC_PRICE      = 32'd4_124_500;

    logic clk;
    logic reset;

    logic [7:0]  data_in;
    logic        data_valid;
    logic        data_start;
    logic        data_last;
    logic [15:0] message_length;

    logic        event_valid;
    itch_event_pkg::itch_event_t event_data;
    logic        unsupported_message;
    logic        parse_error;

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
        .event_valid         (event_valid),
        .event_data          (event_data),
        .unsupported_message (unsupported_message),
        .parse_error         (parse_error)
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

    task automatic drive_u64_last(input logic [63:0] value);
        begin
            drive_byte(value[63:56], 1'b0, 1'b0);
            drive_byte(value[55:48], 1'b0, 1'b0);
            drive_byte(value[47:40], 1'b0, 1'b0);
            drive_byte(value[39:32], 1'b0, 1'b0);
            drive_byte(value[31:24], 1'b0, 1'b0);
            drive_byte(value[23:16], 1'b0, 1'b0);
            drive_byte(value[15:8],  1'b0, 1'b0);
            drive_byte(value[7:0],   1'b0, 1'b1);
        end
    endtask

    task automatic send_order_header(input logic [7:0] message_type);
        begin
            drive_byte(message_type, 1'b1, 1'b0);
            drive_u16(TEST_STOCK_LOCATE);
            drive_u16(TEST_TRACKING_NUMBER);
            drive_u48(TEST_TIMESTAMP);
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

    task automatic send_execute_message(
        input logic [7:0] message_type,
        input logic [15:0] supplied_length
    );
        begin
            message_length = supplied_length;
            send_order_header(message_type);
            drive_u64(TEST_ORDER_REFERENCE);
            drive_u32(TEST_SHARES, 1'b0);
            if (message_type == MSG_ORDER_EXECUTED) begin
                drive_u64_last(TEST_MATCH_NUMBER);
            end else begin
                drive_u64(TEST_MATCH_NUMBER);
                drive_byte("Y", 1'b0, 1'b0);
                drive_u32(TEST_EXEC_PRICE, 1'b1);
            end
            @(posedge clk); #1;
        end
    endtask

    task automatic send_cancel_message(input logic [15:0] supplied_length);
        begin
            message_length = supplied_length;
            send_order_header(MSG_ORDER_CANCEL);
            drive_u64(TEST_ORDER_REFERENCE);
            drive_u32(TEST_SHARES, 1'b1);
            @(posedge clk); #1;
        end
    endtask

    task automatic send_delete_message(input logic [15:0] supplied_length);
        begin
            message_length = supplied_length;
            send_order_header(MSG_ORDER_DELETE);
            drive_u64_last(TEST_ORDER_REFERENCE);
            @(posedge clk); #1;
        end
    endtask

    task automatic send_replace_message(input logic [15:0] supplied_length);
        begin
            message_length = supplied_length;
            send_order_header(MSG_ORDER_REPLACE);
            drive_u64(TEST_ORDER_REFERENCE);
            drive_u64(TEST_NEW_REFERENCE);
            drive_u32(TEST_SHARES, 1'b0);
            drive_u32(TEST_PRICE, 1'b1);
            @(posedge clk); #1;
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
        check_value("event_valid",         event_valid,         1'b1);
        check_value("event_type",          event_data.event_type, MSG_ORDER_ADD);
        check_value("unsupported_message", unsupported_message, 1'b0);
        check_value("parse_error",         parse_error,         1'b0);
        check_add_fields();
        check_value("has_mpid", event_data.has_mpid, 1'b0);
        idle_bus();

        $display("\nTEST 2: dispatcher safely consumes unsupported S message");
        send_unsupported_system_event();
        check_value("unsupported_message", unsupported_message, 1'b1);
        check_value("parse_error",         parse_error,         1'b0);
        check_value("event_valid",         event_valid,         1'b0);
        idle_bus();

        $display("\nTEST 3: dispatcher returns to ADD route after unsupported message");
        send_add_message(MSG_ORDER_ADD_MPID);
        check_value("event_type",          event_data.event_type, MSG_ORDER_ADD_MPID);
        check_value("unsupported_message", unsupported_message, 1'b0);
        check_value("parse_error",         parse_error,         1'b0);
        check_add_fields();
        check_value("has_mpid", event_data.has_mpid, 1'b1);
        check_value("mpid",     event_data.mpid,     TEST_MPID);
        idle_bus();

        $display("\nTEST 4: dispatcher routes E and normalizes an execution");
        send_execute_message(MSG_ORDER_EXECUTED, LEN_ORDER_EXECUTED);
        check_value("event_valid",         event_valid,         1'b1);
        check_value("event_type",          event_data.event_type, MSG_ORDER_EXECUTED);
        check_value("order_reference",     event_data.order_reference, TEST_ORDER_REFERENCE);
        check_value("shares",              event_data.shares, TEST_SHARES);
        check_value("match_number",        event_data.match_number, TEST_MATCH_NUMBER);
        check_value("has_execution_price", event_data.has_execution_price, 1'b0);
        check_value("stock cleared",       event_data.stock, 64'b0);
        check_value("side cleared",        event_data.side, 8'b0);
        idle_bus();

        $display("\nTEST 5: dispatcher routes C and preserves execution details");
        send_execute_message(MSG_ORDER_EXECUTED_PRICE, LEN_ORDER_EXECUTED_PRICE);
        check_value("event_type",          event_data.event_type, MSG_ORDER_EXECUTED_PRICE);
        check_value("match_number",        event_data.match_number, TEST_MATCH_NUMBER);
        check_value("has_execution_price", event_data.has_execution_price, 1'b1);
        check_value("printable",           event_data.printable, "Y");
        check_value("execution price",     event_data.price, TEST_EXEC_PRICE);
        idle_bus();

        $display("\nTEST 6: dispatcher routes X and maps canceled shares");
        send_cancel_message(LEN_ORDER_CANCEL);
        check_value("event_type",      event_data.event_type, MSG_ORDER_CANCEL);
        check_value("order_reference", event_data.order_reference, TEST_ORDER_REFERENCE);
        check_value("shares",          event_data.shares, TEST_SHARES);
        check_value("price cleared",   event_data.price, 32'b0);
        idle_bus();

        $display("\nTEST 7: dispatcher routes D and clears unused payload fields");
        send_delete_message(LEN_ORDER_DELETE);
        check_value("event_type",      event_data.event_type, MSG_ORDER_DELETE);
        check_value("order_reference", event_data.order_reference, TEST_ORDER_REFERENCE);
        check_value("shares cleared",  event_data.shares, 32'b0);
        check_value("price cleared",   event_data.price, 32'b0);
        idle_bus();

        $display("\nTEST 8: dispatcher routes U and normalizes both references");
        send_replace_message(LEN_ORDER_REPLACE);
        check_value("event_type",          event_data.event_type, MSG_ORDER_REPLACE);
        check_value("order_reference",     event_data.order_reference, TEST_ORDER_REFERENCE);
        check_value("new_order_reference", event_data.new_order_reference, TEST_NEW_REFERENCE);
        check_value("shares",              event_data.shares, TEST_SHARES);
        check_value("price",               event_data.price, TEST_PRICE);
        idle_bus();

        $display("\nTEST 9: modify parsers reject incorrect MoldUDP64 lengths");
        send_execute_message(MSG_ORDER_EXECUTED, LEN_ORDER_EXECUTED - 1);
        check_value("execute bad length valid", event_valid, 1'b0);
        check_value("execute bad length error", parse_error, 1'b1);
        idle_bus();
        send_cancel_message(LEN_ORDER_CANCEL - 1);
        check_value("cancel bad length valid", event_valid, 1'b0);
        check_value("cancel bad length error", parse_error, 1'b1);
        idle_bus();
        send_delete_message(LEN_ORDER_DELETE - 1);
        check_value("delete bad length valid", event_valid, 1'b0);
        check_value("delete bad length error", parse_error, 1'b1);
        idle_bus();
        send_replace_message(LEN_ORDER_REPLACE - 1);
        check_value("replace bad length valid", event_valid, 1'b0);
        check_value("replace bad length error", parse_error, 1'b1);
        idle_bus();

        $display("\nTEST 10: byte arriving without data_start produces router error");
        message_length = 16'd1;
        drive_byte(8'hAA, 1'b0, 1'b1);
        @(posedge clk);
        #1;
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
