`timescale 1ns/1ps

module itch_pipeline_tb;

    import itch_event_pkg::*;

    localparam time PARSER_PERIOD = 10ns;
    localparam time EVENT_PERIOD  = 6ns;

    localparam logic [15:0] TEST_STOCK_LOCATE = 16'h1234;
    localparam logic [15:0] TEST_TRACKING     = 16'h5678;
    localparam logic [47:0] TEST_TIMESTAMP    = 48'h010203040506;
    localparam logic [63:0] TEST_REFERENCE    = 64'h1122334455667788;
    localparam logic [31:0] TEST_SHARES       = 32'd1000;
    localparam logic [63:0] TEST_STOCK        = "AAPL    ";
    localparam logic [31:0] TEST_PRICE        = 32'd1_850_000;

    logic parser_clk = 1'b0;
    logic event_clk = 1'b0;
    logic parser_reset, event_reset;
    logic [7:0] data_in;
    logic data_valid, data_start, data_last;
    logic [15:0] message_length;
    logic event_valid, event_ready;
    itch_event_t event_data;
    logic unsupported_message, parse_error;
    logic fifo_write_ready, fifo_overflow;
    integer errors;

    always #(PARSER_PERIOD / 2) parser_clk = ~parser_clk;
    always #(EVENT_PERIOD / 2) event_clk = ~event_clk;

    itch_pipeline #(.EVENT_FIFO_DEPTH(8)) dut (
        .parser_clk(parser_clk), .parser_reset(parser_reset),
        .data_in(data_in), .data_valid(data_valid), .data_start(data_start),
        .data_last(data_last), .message_length(message_length),
        .event_clk(event_clk), .event_reset(event_reset),
        .event_valid(event_valid), .event_ready(event_ready), .event_data(event_data),
        .unsupported_message(unsupported_message), .parse_error(parse_error),
        .fifo_write_ready(fifo_write_ready), .fifo_overflow(fifo_overflow)
    );

    task automatic drive_byte(
        input logic [7:0] value,
        input logic first,
        input logic last
    );
        begin
            @(negedge parser_clk);
            data_in = value;
            data_valid = 1'b1;
            data_start = first;
            data_last = last;
        end
    endtask

    task automatic drive_u16(input logic [15:0] value);
        begin
            drive_byte(value[15:8], 1'b0, 1'b0);
            drive_byte(value[7:0], 1'b0, 1'b0);
        end
    endtask

    task automatic drive_u32(input logic [31:0] value, input logic last);
        begin
            drive_byte(value[31:24], 1'b0, 1'b0);
            drive_byte(value[23:16], 1'b0, 1'b0);
            drive_byte(value[15:8], 1'b0, 1'b0);
            drive_byte(value[7:0], 1'b0, last);
        end
    endtask

    task automatic drive_u48(input logic [47:0] value);
        integer byte_number;
        begin
            for (byte_number = 5; byte_number >= 0; byte_number = byte_number - 1)
                drive_byte(value[byte_number*8 +: 8], 1'b0, 1'b0);
        end
    endtask

    task automatic drive_u64(input logic [63:0] value);
        integer byte_number;
        begin
            for (byte_number = 7; byte_number >= 0; byte_number = byte_number - 1)
                drive_byte(value[byte_number*8 +: 8], 1'b0, 1'b0);
        end
    endtask

    initial begin
        string vcd_path;
        integer cycles;

        if (!$value$plusargs("VCD=%s", vcd_path))
            vcd_path = "build/waves/itch/itch_pipeline_tb.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, itch_pipeline_tb);

        errors = 0;
        parser_reset = 1'b1;
        event_reset = 1'b1;
        data_in = '0;
        data_valid = 1'b0;
        data_start = 1'b0;
        data_last = 1'b0;
        message_length = LEN_ORDER_ADD;
        event_ready = 1'b0;

        repeat (4) @(posedge parser_clk);
        repeat (4) @(posedge event_clk);
        parser_reset = 1'b0;
        event_reset = 1'b0;

        drive_byte(MSG_ORDER_ADD, 1'b1, 1'b0);
        drive_u16(TEST_STOCK_LOCATE);
        drive_u16(TEST_TRACKING);
        drive_u48(TEST_TIMESTAMP);
        drive_u64(TEST_REFERENCE);
        drive_byte("B", 1'b0, 1'b0);
        drive_u32(TEST_SHARES, 1'b0);
        drive_u64(TEST_STOCK);
        drive_u32(TEST_PRICE, 1'b1);

        @(negedge parser_clk);
        data_valid = 1'b0;
        data_start = 1'b0;
        data_last = 1'b0;
        event_ready = 1'b1;

        cycles = 0;
        while (!event_valid && cycles < 30) begin
            @(negedge event_clk);
            cycles = cycles + 1;
        end

        if (!event_valid) begin
            $error("timed out waiting for the parsed FIFO event");
            errors = errors + 1;
        end else begin
            if (event_data.event_type !== MSG_ORDER_ADD) errors = errors + 1;
            if (event_data.stock_locate !== TEST_STOCK_LOCATE) errors = errors + 1;
            if (event_data.tracking_number !== TEST_TRACKING) errors = errors + 1;
            if (event_data.timestamp !== TEST_TIMESTAMP) errors = errors + 1;
            if (event_data.order_reference !== TEST_REFERENCE) errors = errors + 1;
            if (event_data.side !== "B") errors = errors + 1;
            if (event_data.shares !== TEST_SHARES) errors = errors + 1;
            if (event_data.stock !== TEST_STOCK) errors = errors + 1;
            if (event_data.price !== TEST_PRICE) errors = errors + 1;
        end

        if (parse_error || unsupported_message || fifo_overflow) begin
            $error("unexpected pipeline status: parse=%b unsupported=%b overflow=%b",
                   parse_error, unsupported_message, fifo_overflow);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: itch parser-to-FIFO pipeline");
        else
            $fatal(1, "FAIL: itch parser-to-FIFO pipeline (%0d errors)", errors);

        $finish;
    end

endmodule
