`timescale 1ns/1ps

module moldudp64_decoder_tb;

    localparam time CLOCK_PERIOD = 10ns;

    logic clk = 1'b0;
    logic reset;
    logic [7:0] data_in;
    logic udp_payload_valid;
    logic udp_payload_start;
    logic udp_payload_last;

    logic [7:0] data_out;
    logic itch_msg_valid;
    logic itch_msg_start;
    logic itch_msg_last;
    logic [15:0] itch_msg_length;

    integer errors;
    integer output_byte_count;
    integer i;

    always #(CLOCK_PERIOD / 2) clk = ~clk;

    moldudp64_decoder dut (
        .clk               (clk),
        .reset             (reset),
        .data_in           (data_in),
        .udp_payload_valid (udp_payload_valid),
        .udp_payload_start (udp_payload_start),
        .udp_payload_last  (udp_payload_last),
        .data_out          (data_out),
        .itch_msg_valid    (itch_msg_valid),
        .itch_msg_start    (itch_msg_start),
        .itch_msg_last     (itch_msg_last),
        .itch_msg_length   (itch_msg_length)
    );

    task automatic drive_byte(
        input logic [7:0] value,
        input logic       first,
        input logic       last
    );
        begin
            @(negedge clk);
            data_in = value;
            udp_payload_valid = 1'b1;
            udp_payload_start = first;
            udp_payload_last = last;
        end
    endtask

    task automatic drive_idle;
        begin
            @(negedge clk);
            data_in = 8'b0;
            udp_payload_valid = 1'b0;
            udp_payload_start = 1'b0;
            udp_payload_last = 1'b0;
        end
    endtask

    function automatic logic [7:0] expected_data(input integer index);
        case (index)
            0: expected_data = 8'h11;
            1: expected_data = 8'h22;
            2: expected_data = 8'h33;
            3: expected_data = 8'hAA;
            4: expected_data = 8'hBB;
            default: expected_data = 8'hxx;
        endcase
    endfunction

    // Sample in the middle of each input beat, while the decoder's
    // combinational output corresponds to the byte currently being driven.
    always @(negedge clk) begin
        #1;
        if (!reset && itch_msg_valid) begin
            if (output_byte_count >= 5) begin
                $error("unexpected output byte 0x%02h", data_out);
                errors = errors + 1;
            end else begin
                if (data_out !== expected_data(output_byte_count)) begin
                    $error("output byte %0d: expected 0x%02h, got 0x%02h",
                           output_byte_count, expected_data(output_byte_count), data_out);
                    errors = errors + 1;
                end

                if (itch_msg_length !== ((output_byte_count < 3) ? 16'd3 : 16'd2)) begin
                    $error("output byte %0d has incorrect message length %0d",
                           output_byte_count, itch_msg_length);
                    errors = errors + 1;
                end

                if (itch_msg_start !== ((output_byte_count == 0) ||
                                        (output_byte_count == 3))) begin
                    $error("output byte %0d has incorrect start flag", output_byte_count);
                    errors = errors + 1;
                end

                if (itch_msg_last !== ((output_byte_count == 2) ||
                                       (output_byte_count == 4))) begin
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
            vcd_path = "build/sim/test-moldudp64/moldudp64_decoder_tb.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, moldudp64_decoder_tb);

        errors = 0;
        output_byte_count = 0;
        reset = 1'b1;
        data_in = 8'b0;
        udp_payload_valid = 1'b0;
        udp_payload_start = 1'b0;
        udp_payload_last = 1'b0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        // 20-byte MoldUDP64 header: 10-byte session, 8-byte sequence
        // number, and a big-endian message count of two.
        for (i = 0; i < 18; i = i + 1)
            drive_byte(i[7:0], i == 0, 1'b0);
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h02, 1'b0, 1'b0);

        // Two length-prefixed messages in one UDP payload.
        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h03, 1'b0, 1'b0);
        drive_byte(8'h11, 1'b0, 1'b0);
        drive_byte(8'h22, 1'b0, 1'b0);
        drive_byte(8'h33, 1'b0, 1'b0);

        drive_byte(8'h00, 1'b0, 1'b0);
        drive_byte(8'h02, 1'b0, 1'b0);
        drive_byte(8'hAA, 1'b0, 1'b0);
        drive_byte(8'hBB, 1'b0, 1'b1);
        drive_idle();

        repeat (2) @(posedge clk);

        if (output_byte_count !== 5) begin
            $error("expected 5 output bytes, got %0d", output_byte_count);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: decoded two MoldUDP64 messages");
            $finish;
        end else begin
            $fatal(1, "FAIL: moldudp64_decoder (%0d errors)", errors);
        end
    end

endmodule
