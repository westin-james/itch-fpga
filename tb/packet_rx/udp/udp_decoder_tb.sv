`timescale 1ns/1ps

module udp_decoder_tb;

    localparam time CLOCK_PERIOD = 10ns;
    localparam logic [15:0] EXPECTED_PORT = 16'h1234;

    logic clk = 1'b0;
    logic reset;
    logic [7:0] data_in;
    logic ipv4_payload_valid;
    logic ipv4_payload_start;
    logic ipv4_payload_last;

    logic [7:0] data_out;
    logic udp_payload_valid;
    logic udp_payload_start;
    logic udp_payload_last;

    logic [7:0] expected_data [0:9];
    logic expected_start [0:9];
    logic expected_last [0:9];

    integer errors;
    integer output_byte_count;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    udp_decoder dut (
        .clk                (clk),
        .reset              (reset),
        .data_in            (data_in),
        .ipv4_payload_valid (ipv4_payload_valid),
        .ipv4_payload_start (ipv4_payload_start),
        .ipv4_payload_last  (ipv4_payload_last),
        .expected_dest_port (EXPECTED_PORT),
        .data_out           (data_out),
        .udp_payload_valid  (udp_payload_valid),
        .udp_payload_start  (udp_payload_start),
        .udp_payload_last   (udp_payload_last)
    );

    task automatic drive_byte(
        input logic [7:0] value,
        input logic first,
        input logic last
    );
        begin
            @(negedge clk);
            data_in = value;
            ipv4_payload_valid = 1'b1;
            ipv4_payload_start = first;
            ipv4_payload_last = last;
        end
    endtask

    task automatic drive_idle;
        begin
            @(negedge clk);
            data_in = 8'b0;
            ipv4_payload_valid = 1'b0;
            ipv4_payload_start = 1'b0;
            ipv4_payload_last = 1'b0;
        end
    endtask

    task automatic drive_header(
        input logic [15:0] dest_port,
        input logic [15:0] udp_length,
        input logic last_on_header
    );
        begin
            drive_byte(8'hAB, 1'b1, 1'b0);
            drive_byte(8'hCD, 1'b0, 1'b0);
            drive_byte(dest_port[15:8], 1'b0, 1'b0);
            drive_byte(dest_port[7:0], 1'b0, 1'b0);
            drive_byte(udp_length[15:8], 1'b0, 1'b0);
            drive_byte(udp_length[7:0], 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, 1'b0);
            drive_byte(8'h00, 1'b0, last_on_header);
        end
    endtask

    // The decoder outputs the current input byte combinationally. Sample after
    // the testbench has changed the input on each falling edge.
    always @(negedge clk) begin
        #1;
        if (!reset && udp_payload_valid) begin
            if (output_byte_count >= 10) begin
                $error("unexpected UDP output byte 0x%02h", data_out);
                errors = errors + 1;
            end else begin
                if (data_out !== expected_data[output_byte_count]) begin
                    $error("output byte %0d: expected 0x%02h, got 0x%02h",
                           output_byte_count, expected_data[output_byte_count], data_out);
                    errors = errors + 1;
                end
                if (udp_payload_start !== expected_start[output_byte_count]) begin
                    $error("output byte %0d has incorrect start flag", output_byte_count);
                    errors = errors + 1;
                end
                if (udp_payload_last !== expected_last[output_byte_count]) begin
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
            vcd_path = "build/sim/test-udp/udp_decoder_tb.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, udp_decoder_tb);

        expected_data[0] = 8'hA1; expected_start[0] = 1'b1; expected_last[0] = 1'b0;
        expected_data[1] = 8'hB2; expected_start[1] = 1'b0; expected_last[1] = 1'b0;
        expected_data[2] = 8'hC3; expected_start[2] = 1'b0; expected_last[2] = 1'b1;
        expected_data[3] = 8'hD4; expected_start[3] = 1'b1; expected_last[3] = 1'b0;
        expected_data[4] = 8'hE5; expected_start[4] = 1'b0; expected_last[4] = 1'b1;
        expected_data[5] = 8'hF1; expected_start[5] = 1'b1; expected_last[5] = 1'b0;
        expected_data[6] = 8'hF2; expected_start[6] = 1'b0; expected_last[6] = 1'b1;
        expected_data[7] = 8'h31; expected_start[7] = 1'b1; expected_last[7] = 1'b1;
        expected_data[8] = 8'h41; expected_start[8] = 1'b1; expected_last[8] = 1'b1;
        expected_data[9] = 8'h42; expected_start[9] = 1'b1; expected_last[9] = 1'b1;

        errors = 0;
        output_byte_count = 0;
        reset = 1'b1;
        data_in = 8'b0;
        ipv4_payload_valid = 1'b0;
        ipv4_payload_start = 1'b0;
        ipv4_payload_last = 1'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // A normal accepted packet. The UDP length includes its 8-byte header.
        drive_header(EXPECTED_PORT, 16'd11, 1'b0);
        drive_byte(8'hA1, 1'b0, 1'b0);
        drive_byte(8'hB2, 1'b0, 1'b0);
        drive_byte(8'hC3, 1'b0, 1'b1);

        // A complete packet for a different destination must be suppressed.
        drive_header(16'h5678, 16'd10, 1'b0);
        drive_byte(8'h99, 1'b0, 1'b0);
        drive_byte(8'h88, 1'b0, 1'b1);

        // Valid gaps may occur in the header and payload. IPv4 padding after
        // the declared UDP length is not part of the UDP payload.
        drive_byte(8'hAB, 1'b1, 1'b0);
        drive_idle();
        drive_byte(8'hCD, 1'b0, 1'b0);
        drive_byte(EXPECTED_PORT[15:8], 1'b0, 1'b0);
        drive_idle();
        drive_byte(EXPECTED_PORT[7:0], 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h0A, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_idle();
        drive_byte(8'hD4, 1'b0, 1'b0);
        drive_idle();
        drive_byte(8'hE5, 1'b0, 1'b0);
        drive_byte(8'hEE, 1'b0, 1'b1);

        // A truncated payload terminates the emitted payload on the IPv4
        // boundary even though the UDP length promised more bytes.
        drive_header(EXPECTED_PORT, 16'd12, 1'b0);
        drive_byte(8'hF1, 1'b0, 1'b0);
        drive_byte(8'hF2, 1'b0, 1'b1);

        // Truncated headers and impossible/no-payload lengths produce nothing
        // and must not prevent the packet immediately following them.
        drive_byte(8'hAB, 1'b1, 1'b0);
        drive_byte(8'hCD, 1'b0, 1'b0);
        drive_byte(8'h12, 1'b0, 1'b0);
        drive_byte(8'h34, 1'b0, 1'b1);
        drive_header(EXPECTED_PORT, 16'd7, 1'b1);
        drive_header(EXPECTED_PORT, 16'd9, 1'b0);
        drive_byte(8'h31, 1'b0, 1'b1);

        // A one-byte packet followed immediately by another packet exercises
        // both flags on one beat and back-to-back packet boundaries.
        drive_header(EXPECTED_PORT, 16'd9, 1'b0);
        drive_byte(8'h41, 1'b0, 1'b1);
        drive_header(EXPECTED_PORT, 16'd9, 1'b0);
        drive_byte(8'h42, 1'b0, 1'b1);
        drive_idle();

        repeat (2) @(posedge clk);

        if (output_byte_count !== 10) begin
            $error("expected 10 UDP payload bytes, got %0d", output_byte_count);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: UDP decoding, filtering, gaps, and packet boundaries");
        else
            $fatal(1, "FAIL: udp_decoder (%0d errors)", errors);

        $finish;
    end

endmodule
