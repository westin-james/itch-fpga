`timescale 1ns/1ps

module ethernet_decoder_tb;

    localparam time CLOCK_PERIOD = 10ns;
    localparam logic [47:0] EXPECTED_MAC = 48'h02_00_00_00_00_01;

    logic clk = 1'b0;
    logic reset;
    logic [7:0] data_in;
    logic frame_valid;
    logic frame_start;
    logic frame_last;

    logic [7:0] data_out;
    logic ethernet_payload_valid;
    logic ethernet_payload_start;
    logic ethernet_payload_last;

    logic [7:0] expected_data [0:13];
    logic expected_start [0:13];
    logic expected_last [0:13];

    integer errors;
    integer output_byte_count;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    ethernet_decoder dut (
        .clk                    (clk),
        .reset                  (reset),
        .data_in                (data_in),
        .frame_valid            (frame_valid),
        .frame_start            (frame_start),
        .frame_last             (frame_last),
        .expected_dest_mac      (EXPECTED_MAC),
        .data_out               (data_out),
        .ethernet_payload_valid (ethernet_payload_valid),
        .ethernet_payload_start (ethernet_payload_start),
        .ethernet_payload_last  (ethernet_payload_last)
    );

    task automatic drive_byte(
        input logic [7:0] value,
        input logic first,
        input logic last
    );
        begin
            @(negedge clk);
            data_in = value;
            frame_valid = 1'b1;
            frame_start = first;
            frame_last = last;
        end
    endtask

    task automatic drive_idle;
        begin
            @(negedge clk);
            data_in = 8'b0;
            frame_valid = 1'b0;
            frame_start = 1'b0;
            frame_last = 1'b0;
        end
    endtask

    task automatic drive_header(
        input logic [47:0] dest_mac,
        input logic [15:0] ethertype,
        input logic gap_in_header,
        input logic last_on_header
    );
        integer byte_number;
        begin
            for (byte_number = 5; byte_number >= 0; byte_number = byte_number - 1) begin
                drive_byte(dest_mac[byte_number*8 +: 8],
                           byte_number == 5, 1'b0);
                if (gap_in_header && byte_number == 3)
                    drive_idle();
            end
            for (byte_number = 0; byte_number < 6; byte_number = byte_number + 1)
                drive_byte(8'hA0 + byte_number[7:0], 1'b0, 1'b0);
            drive_byte(ethertype[15:8], 1'b0, 1'b0);
            drive_byte(ethertype[7:0], 1'b0, last_on_header);
        end
    endtask

    // The decoder forwards the current input byte combinationally. Sample
    // after the testbench has changed the input on each falling edge.
    always @(negedge clk) begin
        #1;
        if (!reset && ethernet_payload_valid) begin
            if (output_byte_count >= 14) begin
                $error("unexpected Ethernet output byte 0x%02h", data_out);
                errors = errors + 1;
            end else begin
                if (data_out !== expected_data[output_byte_count]) begin
                    $error("output byte %0d: expected 0x%02h, got 0x%02h",
                           output_byte_count, expected_data[output_byte_count], data_out);
                    errors = errors + 1;
                end
                if (ethernet_payload_start !== expected_start[output_byte_count]) begin
                    $error("output byte %0d has incorrect start flag", output_byte_count);
                    errors = errors + 1;
                end
                if (ethernet_payload_last !== expected_last[output_byte_count]) begin
                    $error("output byte %0d has incorrect last flag", output_byte_count);
                    errors = errors + 1;
                end
            end
            output_byte_count = output_byte_count + 1;
        end
    end

    initial begin
        string vcd_path;

        if (!$value$plusargs("VCD=%s", vcd_path))
            vcd_path = "build/waves/itch/ethernet_decoder_tb.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, ethernet_decoder_tb);

        expected_data[0]  = 8'h45; expected_start[0]  = 1'b1; expected_last[0]  = 1'b0;
        expected_data[1]  = 8'hA1; expected_start[1]  = 1'b0; expected_last[1]  = 1'b0;
        expected_data[2]  = 8'hA2; expected_start[2]  = 1'b0; expected_last[2]  = 1'b1;
        expected_data[3]  = 8'hB1; expected_start[3]  = 1'b1; expected_last[3]  = 1'b0;
        expected_data[4]  = 8'hB2; expected_start[4]  = 1'b0; expected_last[4]  = 1'b1;
        expected_data[5]  = 8'hC1; expected_start[5]  = 1'b1; expected_last[5]  = 1'b1;
        expected_data[6]  = 8'hD1; expected_start[6]  = 1'b1; expected_last[6]  = 1'b0;
        expected_data[7]  = 8'hD2; expected_start[7]  = 1'b0; expected_last[7]  = 1'b1;
        expected_data[8]  = 8'hE1; expected_start[8]  = 1'b1; expected_last[8]  = 1'b0;
        expected_data[9]  = 8'hE2; expected_start[9]  = 1'b0; expected_last[9]  = 1'b0;
        expected_data[10] = 8'h00; expected_start[10] = 1'b0; expected_last[10] = 1'b0;
        expected_data[11] = 8'h00; expected_start[11] = 1'b0; expected_last[11] = 1'b1;
        expected_data[12] = 8'hF1; expected_start[12] = 1'b1; expected_last[12] = 1'b1;
        expected_data[13] = 8'hF2; expected_start[13] = 1'b1; expected_last[13] = 1'b1;

        errors = 0;
        output_byte_count = 0;
        reset = 1'b1;
        data_in = 8'b0;
        frame_valid = 1'b0;
        frame_start = 1'b0;
        frame_last = 1'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Normal Ethernet II IPv4 frame forwarding.
        drive_header(EXPECTED_MAC, 16'h0800, 1'b0, 1'b0);
        drive_byte(8'h45, 1'b0, 1'b0);
        drive_byte(8'hA1, 1'b0, 1'b0);
        drive_byte(8'hA2, 1'b0, 1'b1);

        // Destination-MAC and EtherType filtering suppress complete frames.
        drive_header(48'h02_00_00_00_00_02, 16'h0800, 1'b0, 1'b0);
        drive_byte(8'h91, 1'b0, 1'b1);
        drive_header(EXPECTED_MAC, 16'h86DD, 1'b0, 1'b0);
        drive_byte(8'h92, 1'b0, 1'b1);

        // Valid gaps do not advance header or payload byte position.
        drive_header(EXPECTED_MAC, 16'h0800, 1'b1, 1'b0);
        drive_idle();
        drive_byte(8'hB1, 1'b0, 1'b0);
        drive_idle();
        drive_byte(8'hB2, 1'b0, 1'b1);

        // A one-byte payload carries start and last together. A new frame may
        // begin immediately after the preceding frame's last byte.
        drive_header(EXPECTED_MAC, 16'h0800, 1'b0, 1'b0);
        drive_byte(8'hC1, 1'b0, 1'b1);
        drive_header(EXPECTED_MAC, 16'h0800, 1'b0, 1'b0);
        drive_byte(8'hD1, 1'b0, 1'b0);
        drive_byte(8'hD2, 1'b0, 1'b1);

        // Ethernet has no payload-length field, so padding remains part of
        // its output stream for the IPv4 decoder to trim by total_length.
        drive_header(EXPECTED_MAC, 16'h0800, 1'b0, 1'b0);
        drive_byte(8'hE1, 1'b0, 1'b0);
        drive_byte(8'hE2, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b1);

        // Truncated frames at several header boundaries produce no output and
        // must recover for the next complete frame.
        drive_byte(8'h02, 1'b1, 1'b1);
        drive_byte(8'h02, 1'b1, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b1);
        drive_header(EXPECTED_MAC, 16'h0800, 1'b0, 1'b1);
        drive_header(EXPECTED_MAC, 16'h0800, 1'b0, 1'b0);
        drive_byte(8'hF1, 1'b0, 1'b1);

        // A start flag without valid is ignored rather than opening a packet.
        @(negedge clk);
        data_in = 8'h02;
        frame_valid = 1'b0;
        frame_start = 1'b1;
        frame_last = 1'b0;
        drive_byte(8'hAA, 1'b0, 1'b1);
        drive_header(EXPECTED_MAC, 16'h0800, 1'b0, 1'b0);
        drive_byte(8'hF2, 1'b0, 1'b1);
        drive_idle();

        repeat (2) @(posedge clk);

        if (output_byte_count !== 14) begin
            $error("expected 14 Ethernet payload bytes, got %0d", output_byte_count);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: Ethernet decoding, filtering, gaps, padding, and boundaries");
        else
            $fatal(1, "FAIL: ethernet_decoder (%0d errors)", errors);

        $finish;
    end

endmodule
