`timescale 1ns/1ps

module ipv4_decoder_tb;

    localparam time CLOCK_PERIOD = 10ns;
    localparam logic [31:0] EXPECTED_IP = 32'hC0A8_0164;

    logic clk = 1'b0;
    logic reset;
    logic [7:0] data_in;
    logic ethernet_payload_valid;
    logic ethernet_payload_start;
    logic ethernet_payload_last;

    logic [7:0] data_out;
    logic ipv4_payload_valid;
    logic ipv4_payload_start;
    logic ipv4_payload_last;

    logic [7:0] expected_data [0:12];
    logic expected_start [0:12];
    logic expected_last [0:12];

    integer errors;
    integer output_byte_count;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    ipv4_decoder dut (
        .clk                    (clk),
        .reset                  (reset),
        .data_in                (data_in),
        .ethernet_payload_valid (ethernet_payload_valid),
        .ethernet_payload_start (ethernet_payload_start),
        .ethernet_payload_last  (ethernet_payload_last),
        .expected_dest_ip       (EXPECTED_IP),
        .data_out               (data_out),
        .ipv4_payload_valid     (ipv4_payload_valid),
        .ipv4_payload_start     (ipv4_payload_start),
        .ipv4_payload_last      (ipv4_payload_last)
    );

    task automatic drive_byte(
        input logic [7:0] value,
        input logic first,
        input logic last
    );
        begin
            @(negedge clk);
            data_in = value;
            ethernet_payload_valid = 1'b1;
            ethernet_payload_start = first;
            ethernet_payload_last = last;
        end
    endtask

    task automatic drive_idle;
        begin
            @(negedge clk);
            data_in = 8'b0;
            ethernet_payload_valid = 1'b0;
            ethernet_payload_start = 1'b0;
            ethernet_payload_last = 1'b0;
        end
    endtask

    task automatic drive_header(
        input logic [3:0] ihl,
        input logic [15:0] total_length,
        input logic [7:0] protocol,
        input logic [15:0] flags_fragment,
        input logic [31:0] dest_ip,
        input logic last_on_header
    );
        integer option_byte;
        integer option_count;
        begin
            drive_byte({4'd4, ihl}, 1'b1, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(total_length[15:8], 1'b0, 1'b0);
            drive_byte(total_length[7:0], 1'b0, 1'b0);
            drive_byte(8'h12, 1'b0, 1'b0);
            drive_byte(8'h34, 1'b0, 1'b0);
            drive_byte(flags_fragment[15:8], 1'b0, 1'b0);
            drive_byte(flags_fragment[7:0], 1'b0, 1'b0);
            drive_byte(8'd64, 1'b0, 1'b0);
            drive_byte(protocol, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h0A, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h01, 1'b0, 1'b0);
            drive_byte(dest_ip[31:24], 1'b0, 1'b0);
            drive_byte(dest_ip[23:16], 1'b0, 1'b0);
            drive_byte(dest_ip[15:8], 1'b0, 1'b0);

            option_count = (ihl > 4'd5) ? ((ihl - 4'd5) * 4) : 0;
            drive_byte(dest_ip[7:0], 1'b0,
                       last_on_header && (option_count == 0));
            for (option_byte = 0; option_byte < option_count; option_byte = option_byte + 1)
                drive_byte(8'h80 + option_byte[7:0], 1'b0,
                           last_on_header && (option_byte == option_count - 1));
        end
    endtask

    // The decoder forwards the current input byte combinationally. Sample
    // after the testbench has changed the input on each falling edge.
    always @(negedge clk) begin
        #1;
        if (!reset && ipv4_payload_valid) begin
            if (output_byte_count >= 13) begin
                $error("unexpected IPv4 output byte 0x%02h", data_out);
                errors = errors + 1;
            end else begin
                if (data_out !== expected_data[output_byte_count]) begin
                    $error("output byte %0d: expected 0x%02h, got 0x%02h",
                           output_byte_count, expected_data[output_byte_count], data_out);
                    errors = errors + 1;
                end
                if (ipv4_payload_start !== expected_start[output_byte_count]) begin
                    $error("output byte %0d has incorrect start flag", output_byte_count);
                    errors = errors + 1;
                end
                if (ipv4_payload_last !== expected_last[output_byte_count]) begin
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
            vcd_path = "build/sim/test-ipv4/ipv4_decoder_tb.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, ipv4_decoder_tb);

        expected_data[0]  = 8'hA1; expected_start[0]  = 1'b1; expected_last[0]  = 1'b0;
        expected_data[1]  = 8'hA2; expected_start[1]  = 1'b0; expected_last[1]  = 1'b0;
        expected_data[2]  = 8'hA3; expected_start[2]  = 1'b0; expected_last[2]  = 1'b1;
        expected_data[3]  = 8'hB1; expected_start[3]  = 1'b1; expected_last[3]  = 1'b0;
        expected_data[4]  = 8'hB2; expected_start[4]  = 1'b0; expected_last[4]  = 1'b1;
        expected_data[5]  = 8'hC1; expected_start[5]  = 1'b1; expected_last[5]  = 1'b0;
        expected_data[6]  = 8'hC2; expected_start[6]  = 1'b0; expected_last[6]  = 1'b1;
        expected_data[7]  = 8'hD1; expected_start[7]  = 1'b1; expected_last[7]  = 1'b0;
        expected_data[8]  = 8'hD2; expected_start[8]  = 1'b0; expected_last[8]  = 1'b0;
        expected_data[9]  = 8'hD3; expected_start[9]  = 1'b0; expected_last[9]  = 1'b1;
        expected_data[10] = 8'hE1; expected_start[10] = 1'b1; expected_last[10] = 1'b1;
        expected_data[11] = 8'hE2; expected_start[11] = 1'b1; expected_last[11] = 1'b1;
        expected_data[12] = 8'hF1; expected_start[12] = 1'b1; expected_last[12] = 1'b1;

        errors = 0;
        output_byte_count = 0;
        reset = 1'b1;
        data_in = 8'b0;
        ethernet_payload_valid = 1'b0;
        ethernet_payload_start = 1'b0;
        ethernet_payload_last = 1'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // Normal IPv4/UDP payload forwarding.
        drive_header(4'd5, 16'd23, 8'd17, 16'h4000, EXPECTED_IP, 1'b0);
        drive_byte(8'hA1, 1'b0, 1'b0);
        drive_byte(8'hA2, 1'b0, 1'b0);
        drive_byte(8'hA3, 1'b0, 1'b1);

        // Destination filtering, non-UDP traffic, and both forms of IPv4
        // fragmentation must suppress the complete packet.
        drive_header(4'd5, 16'd21, 8'd17, 16'h0000, 32'hC0A8_0165, 1'b0);
        drive_byte(8'h91, 1'b0, 1'b1);
        drive_header(4'd5, 16'd21, 8'd6, 16'h0000, EXPECTED_IP, 1'b0);
        drive_byte(8'h92, 1'b0, 1'b1);
        drive_header(4'd5, 16'd21, 8'd17, 16'h2000, EXPECTED_IP, 1'b0);
        drive_byte(8'h93, 1'b0, 1'b1);
        drive_header(4'd5, 16'd21, 8'd17, 16'h0001, EXPECTED_IP, 1'b0);
        drive_byte(8'h94, 1'b0, 1'b1);

        // IHL six skips four option bytes before marking payload start.
        drive_header(4'd6, 16'd26, 8'd17, 16'h0000, EXPECTED_IP, 1'b0);
        drive_byte(8'hB1, 1'b0, 1'b0);
        drive_byte(8'hB2, 1'b0, 1'b1);

        // Bytes beyond total_length are Ethernet padding. Last belongs on the
        // declared final IPv4 byte, not on the end of the padded frame.
        drive_header(4'd5, 16'd22, 8'd17, 16'h0000, EXPECTED_IP, 1'b0);
        drive_byte(8'hC1, 1'b0, 1'b0);
        drive_byte(8'hC2, 1'b0, 1'b0);
        drive_byte(8'hEE, 1'b0, 1'b0);
        drive_byte(8'hEE, 1'b0, 1'b1);

        // Valid gaps do not advance either header or payload position.
        drive_byte(8'h45, 1'b1, 1'b0);
        drive_idle();
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'd23, 1'b0, 1'b0);
        drive_byte(8'h12, 1'b0, 1'b0);
        drive_byte(8'h34, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'd64, 1'b0, 1'b0);
        drive_idle();
        drive_byte(8'd17, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h0A, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h01, 1'b0, 1'b0);
        drive_byte(EXPECTED_IP[31:24], 1'b0, 1'b0);
        drive_byte(EXPECTED_IP[23:16], 1'b0, 1'b0);
        drive_byte(EXPECTED_IP[15:8], 1'b0, 1'b0);
        drive_byte(EXPECTED_IP[7:0], 1'b0, 1'b0);
        drive_idle();
        drive_byte(8'hD1, 1'b0, 1'b0);
        drive_byte(8'hD2, 1'b0, 1'b0);
        drive_idle();
        drive_byte(8'hD3, 1'b0, 1'b1);

        // Single-byte payloads carry start and last together. Packets may be
        // adjacent without an idle cycle between their frame boundaries.
        drive_header(4'd5, 16'd21, 8'd17, 16'h0000, EXPECTED_IP, 1'b0);
        drive_byte(8'hE1, 1'b0, 1'b1);
        drive_header(4'd5, 16'd21, 8'd17, 16'h0000, EXPECTED_IP, 1'b0);
        drive_byte(8'hE2, 1'b0, 1'b1);

        // Truncated/invalid headers, impossible lengths, and empty packets
        // produce no output and must recover at the frame boundary.
        drive_byte(8'h45, 1'b1, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h20, 1'b0, 1'b1);
        drive_header(4'd4, 16'd20, 8'd17, 16'h0000, EXPECTED_IP, 1'b1);
        drive_header(4'd5, 16'd19, 8'd17, 16'h0000, EXPECTED_IP, 1'b1);
        drive_header(4'd5, 16'd20, 8'd17, 16'h0000, EXPECTED_IP, 1'b1);

        // A truncated accepted payload is terminated at the frame boundary.
        drive_header(4'd5, 16'd24, 8'd17, 16'h0000, EXPECTED_IP, 1'b0);
        drive_byte(8'hF1, 1'b0, 1'b1);
        drive_idle();

        repeat (2) @(posedge clk);

        if (output_byte_count !== 13) begin
            $error("expected 13 IPv4 payload bytes, got %0d", output_byte_count);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: IPv4 decoding, filtering, options, gaps, padding, and boundaries");
        else
            $fatal(1, "FAIL: ipv4_decoder (%0d errors)", errors);

        $finish;
    end

endmodule
