`timescale 1ns/1ps

module event_fifo_tb;

    localparam int unsigned DEPTH = 8;
    localparam time WR_PERIOD = 10ns;
    localparam time RD_PERIOD = 6ns;

    logic wr_clk = 1'b0;
    logic rd_clk = 1'b0;
    logic wr_reset, wr_valid, wr_ready, wr_overflow;
    logic rd_reset, rd_valid, rd_ready;
    itch_event_pkg::itch_event_t wr_data, rd_data;

    integer errors;
    integer received;
    integer i;

    always #(WR_PERIOD / 2) wr_clk = ~wr_clk;
    always #(RD_PERIOD / 2) rd_clk = ~rd_clk;

    event_fifo #(.DEPTH(DEPTH)) dut (
        .wr_clk(wr_clk), .wr_reset(wr_reset), .wr_valid(wr_valid),
        .wr_ready(wr_ready), .wr_data(wr_data), .wr_overflow(wr_overflow),
        .rd_clk(rd_clk), .rd_reset(rd_reset), .rd_valid(rd_valid),
        .rd_ready(rd_ready), .rd_data(rd_data)
    );

    task automatic drive_event(input integer seq_num);
        begin
            @(negedge wr_clk);
            wr_data = '0;
            wr_data.event_type = 8'h40 + seq_num[7:0];
            wr_data.timestamp = seq_num;
            wr_data.order_reference = 64'h1000 + seq_num;
            wr_data.shares = 32'd100 + seq_num;
            wr_valid = 1'b1;
            @(posedge wr_clk);
            #1;
            @(negedge wr_clk);
            wr_valid = 1'b0;
        end
    endtask

    always @(posedge rd_clk) begin
        if (!rd_reset && rd_valid && rd_ready) begin
            if (rd_data.event_type !== (8'h40 + received[7:0])) begin
                $error("event %0d type: expected %0h, got %0h",
                       received, 8'h40 + received[7:0], rd_data.event_type);
                errors = errors + 1;
            end
            if (rd_data.order_reference !== (64'h1000 + received)) begin
                $error("event %0d reference: expected %0h, got %0h",
                       received, 64'h1000 + received, rd_data.order_reference);
                errors = errors + 1;
            end
            if (rd_data.shares !== (32'd100 + received)) begin
                $error("event %0d shares: expected %0d, got %0d",
                       received, 100 + received, rd_data.shares);
                errors = errors + 1;
            end
            received = received + 1;
        end
    end

    initial begin
        string vcd_path;
        if (!$value$plusargs("VCD=%s", vcd_path))
            vcd_path = "build/waves/itch/event_fifo_tb.vcd";
        $dumpfile(vcd_path);
        $dumpvars(0, event_fifo_tb);

        errors = 0;
        received = 0;
        wr_reset = 1'b1;
        rd_reset = 1'b1;
        wr_valid = 1'b0;
        rd_ready = 1'b0;
        wr_data = '0;

        repeat (4) @(posedge wr_clk);
        repeat (4) @(posedge rd_clk);
        @(negedge wr_clk); wr_reset = 1'b0;
        @(negedge rd_clk); rd_reset = 1'b0;

        $display("\nTEST 1: async FIFO fills in write-clock order");
        for (i = 0; i < DEPTH; i = i + 1)
            drive_event(i);
        if (wr_ready !== 1'b0) begin
            $error("wr_ready remained high when FIFO became full");
            errors = errors + 1;
        end

        $display("\nTEST 2: full FIFO rejects a write and reports overflow");
        drive_event(DEPTH);
        if (wr_overflow !== 1'b1) begin
            $error("expected wr_overflow pulse");
            errors = errors + 1;
        end

        $display("\nTEST 3: faster read domain receives all accepted events in order");
        @(negedge rd_clk); rd_ready = 1'b1;
        repeat (80) @(posedge rd_clk);
        if (received !== DEPTH) begin
            $error("expected %0d events, received %0d", DEPTH, received);
            errors = errors + 1;
        end
        if (rd_valid !== 1'b0) begin
            $error("rd_valid remained high after draining FIFO");
            errors = errors + 1;
        end
        if (errors == 0) begin
            $display("\nALL event_fifo TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "\nevent_fifo TESTS FAILED: %0d error(s)", errors);
        end
    end

endmodule
