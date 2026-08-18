`timescale 1ns/1ps

module pipeline_tb;

    import itch_event_pkg::*;

    localparam time PARSER_PERIOD = 10ns;
    localparam time EVENT_PERIOD  = 6ns;
    localparam logic [47:0] EXPECTED_MAC = 48'h02_00_00_00_00_01;
    localparam logic [31:0] EXPECTED_IP = 32'hC0A8_0164;
    localparam logic [15:0] EXPECTED_PORT = 16'h1234;

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
    logic event_valid, event_ready;
    itch_event_t event_data;
    logic unsupported_message, parse_error;
    logic fifo_write_ready, fifo_overflow;
    integer errors;

    always #(PARSER_PERIOD / 2) parser_clk = ~parser_clk;
    always #(EVENT_PERIOD / 2) event_clk = ~event_clk;

    pipeline #(.EVENT_FIFO_DEPTH(8)) dut (
        .parser_clk(parser_clk), .parser_reset(parser_reset),
        .data_in(data_in), .data_valid(data_valid), .data_start(data_start),
        .data_last(data_last), .expected_dest_mac(EXPECTED_MAC),
        .expected_dest_ip(EXPECTED_IP),
        .expected_dest_port(EXPECTED_PORT),
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

    task automatic drive_idle;
        begin
            @(negedge parser_clk);
            data_in = 8'b0;
            data_valid = 1'b0;
            data_start = 1'b0;
            data_last = 1'b0;
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

    task automatic drive_ethernet_header(
        input logic [47:0] dest_mac,
        input logic [15:0] ethertype
    );
        integer byte_number;
        begin
            for (byte_number = 5; byte_number >= 0; byte_number = byte_number - 1)
                drive_byte(dest_mac[byte_number*8 +: 8],
                           byte_number == 5, 1'b0);
            for (byte_number = 0; byte_number < 6; byte_number = byte_number + 1)
                drive_byte(8'hA0 + byte_number[7:0], 1'b0, 1'b0);
            drive_byte(ethertype[15:8], 1'b0, 1'b0);
            drive_byte(ethertype[7:0], 1'b0, 1'b0);
        end
    endtask

    task automatic drive_ipv4_header(input logic [31:0] dest_ip);
        begin
            // 20-byte IPv4 header followed by the 66-byte UDP datagram.
            drive_byte(8'h45, 1'b1, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'd86, 1'b0, 1'b0);
            drive_byte(8'h12, 1'b0, 1'b0);
            drive_byte(8'h34, 1'b0, 1'b0);
            drive_byte(8'h40, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'd64, 1'b0, 1'b0);
            drive_byte(8'd17, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h0A, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h01, 1'b0, 1'b0);
            drive_byte(dest_ip[31:24], 1'b0, 1'b0);
            drive_byte(dest_ip[23:16], 1'b0, 1'b0);
            drive_byte(dest_ip[15:8], 1'b0, 1'b0);
            drive_byte(dest_ip[7:0], 1'b0, 1'b0);
        end
    endtask

    task automatic drive_udp_header(input logic [15:0] dest_port);
        begin
            // 8 UDP header + 20 MoldUDP64 header + 2 length + 36-byte Add.
            drive_byte(8'hAB, 1'b0, 1'b0);
            drive_byte(8'hCD, 1'b0, 1'b0);
            drive_byte(dest_port[15:8], 1'b0, 1'b0);
            drive_byte(dest_port[7:0], 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'd66, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
        end
    endtask

    task automatic drive_mold_header;
        integer byte_number;
        begin
            // Session and sequence number are not interpreted by the decoder.
            for (byte_number = 0; byte_number < 18; byte_number = byte_number + 1)
                drive_byte(byte_number[7:0], 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h01, 1'b0, 1'b0);
        end
    endtask

    task automatic drive_add_message(input logic last);
        begin
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(LEN_ORDER_ADD[7:0], 1'b0, 1'b0);
            drive_byte(MSG_ORDER_ADD, 1'b0, 1'b0);
            drive_u16(TEST_STOCK_LOCATE);
            drive_u16(TEST_TRACKING);
            drive_u48(TEST_TIMESTAMP);
            drive_u64(TEST_REFERENCE);
            drive_byte("B", 1'b0, 1'b0);
            drive_u32(TEST_SHARES, 1'b0);
            drive_u64(TEST_STOCK);
            drive_u32(TEST_PRICE, last);
        end
    endtask

    initial begin
        string vcd_path;
        integer cycles;

        if (!$value$plusargs("VCD=%s", vcd_path))
            vcd_path = "build/sim/test-pipeline/pipeline_tb.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, pipeline_tb);

        errors = 0;
        parser_reset = 1'b1;
        event_reset = 1'b1;
        data_in = '0;
        data_valid = 1'b0;
        data_start = 1'b0;
        data_last = 1'b0;
        event_ready = 1'b0;

        repeat (4) @(posedge parser_clk);
        repeat (4) @(posedge event_clk);
        parser_reset = 1'b0;
        event_reset = 1'b0;

        // A valid IPv4 packet in an Ethernet frame for another MAC must not
        // reach any downstream decoder.
        drive_ethernet_header(48'h02_00_00_00_00_02, 16'h0800);
        drive_ipv4_header(EXPECTED_IP);
        drive_udp_header(EXPECTED_PORT);
        drive_mold_header();
        drive_add_message(1'b1);
        drive_idle();
        repeat (12) @(negedge event_clk);
        if (event_valid) begin
            $error("filtered Ethernet frame unexpectedly produced an event");
            errors = errors + 1;
        end

        // A selected MAC carrying a non-IPv4 EtherType must also be rejected
        // before the downstream protocol decoders.
        drive_ethernet_header(EXPECTED_MAC, 16'h86DD);
        drive_ipv4_header(EXPECTED_IP);
        drive_udp_header(EXPECTED_PORT);
        drive_mold_header();
        drive_add_message(1'b1);
        drive_idle();
        repeat (12) @(negedge event_clk);
        if (event_valid) begin
            $error("non-IPv4 Ethernet frame unexpectedly produced an event");
            errors = errors + 1;
        end

        // A structurally valid packet for another IPv4 destination must not
        // reach the UDP, MoldUDP64, or ITCH stages.
        drive_ethernet_header(EXPECTED_MAC, 16'h0800);
        drive_ipv4_header(32'hC0A8_0165);
        drive_udp_header(EXPECTED_PORT);
        drive_mold_header();
        drive_add_message(1'b1);
        drive_idle();
        repeat (12) @(negedge event_clk);
        if (event_valid) begin
            $error("filtered IPv4 packet unexpectedly produced an event");
            errors = errors + 1;
        end

        // A selected IPv4 packet for another UDP port must not reach the
        // MoldUDP64 or ITCH stages.
        drive_ethernet_header(EXPECTED_MAC, 16'h0800);
        drive_ipv4_header(EXPECTED_IP);
        drive_udp_header(16'h5678);
        drive_mold_header();
        drive_add_message(1'b1);
        drive_idle();
        repeat (12) @(negedge event_clk);
        if (event_valid) begin
            $error("filtered UDP packet unexpectedly produced an event");
            errors = errors + 1;
        end

        // Send the same MoldUDP64 message to the selected MAC, IP, and port.
        // Include an input-valid gap and Ethernet padding; the IPv4 length
        // must stop padding from reaching the downstream protocol decoders.
        drive_ethernet_header(EXPECTED_MAC, 16'h0800);
        drive_ipv4_header(EXPECTED_IP);
        drive_udp_header(EXPECTED_PORT);
        drive_mold_header();
        drive_idle();
        drive_add_message(1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b1);
        drive_idle();

        cycles = 0;
        while (!event_valid && cycles < 40) begin
            @(negedge event_clk);
            cycles = cycles + 1;
        end

        if (!event_valid) begin
            $error("timed out waiting for the UDP/MoldUDP64/ITCH pipeline event");
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

        @(negedge event_clk);
        event_ready = 1'b1;

        if (parse_error || unsupported_message || fifo_overflow) begin
            $error("unexpected pipeline status: parse=%b unsupported=%b overflow=%b",
                   parse_error, unsupported_message, fifo_overflow);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: Ethernet-to-IPv4-to-UDP-to-MoldUDP64-to-ITCH pipeline");
        else
            $fatal(1, "FAIL: pipeline (%0d errors)", errors);

        $finish;
    end

endmodule
