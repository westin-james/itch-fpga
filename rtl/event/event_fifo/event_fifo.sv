`timescale 1ns/1ps

module event_fifo #(
    parameter int unsigned DEPTH = 16
) (
    input  logic                        wr_clk,
    input  logic                        wr_reset,
    input  logic                        wr_valid,
    output logic                        wr_ready,
    input  itch_event_pkg::itch_event_t wr_data,
    output logic                        wr_overflow,

    input  logic                        rd_clk,
    input  logic                        rd_reset,
    output logic                        rd_valid,
    input  logic                        rd_ready,
    output itch_event_pkg::itch_event_t rd_data
);

    localparam int unsigned ADDR_WIDTH = $clog2(DEPTH);
    localparam int unsigned PTR_WIDTH  = ADDR_WIDTH + 1;
    localparam int unsigned DATA_WIDTH = $bits(itch_event_pkg::itch_event_t);

    logic [PTR_WIDTH-1:0] b_wptr, b_rptr;
    logic [PTR_WIDTH-1:0] g_wptr, g_rptr;
    logic [PTR_WIDTH-1:0] g_wptr_sync, g_rptr_sync;
    logic                 full, empty;

    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] g_wptr_sync_ff;
    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] g_rptr_sync_ff;

    initial begin
        if (DEPTH < 4 || (DEPTH & (DEPTH - 1)) != 0)
            $error("event_fifo DEPTH must be a power of two and at least 4");
    end

    assign wr_ready = !full;
    assign rd_valid = !empty;

    // only sync gray coded ptrs between clock domains
    always_ff @(posedge rd_clk) begin
        if (rd_reset) begin
            g_wptr_sync_ff <= '0;
            g_wptr_sync    <= '0;
        end else begin
            g_wptr_sync_ff <= g_wptr;
            g_wptr_sync    <= g_wptr_sync_ff;
        end
    end

    always_ff @(posedge wr_clk) begin
        if (wr_reset) begin
            g_rptr_sync_ff <= '0;
            g_rptr_sync    <= '0;
        end else begin
            g_rptr_sync_ff <= g_rptr;
            g_rptr_sync    <= g_rptr_sync_ff;
        end
    end

    always_ff @(posedge wr_clk) begin
        if (wr_reset)
            wr_overflow <= 1'b0;
        else
            wr_overflow <= wr_valid && !wr_ready;
    end

    wptr_handler #(
        .PTR_WIDTH(PTR_WIDTH)
    ) write_pointer (
        .wclk        (wr_clk),
        .wrst        (wr_reset),
        .w_en        (wr_valid),
        .g_rptr_sync (g_rptr_sync),
        .b_wptr      (b_wptr),
        .g_wptr      (g_wptr),
        .full        (full)
    );

    rptr_handler #(
        .PTR_WIDTH(PTR_WIDTH)
    ) read_pointer (
        .rclk        (rd_clk),
        .rrst        (rd_reset),
        .r_en        (rd_ready),
        .g_wptr_sync (g_wptr_sync),
        .b_rptr      (b_rptr),
        .g_rptr      (g_rptr),
        .empty       (empty)
    );

    fifo_mem #(
        .DEPTH      (DEPTH),
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .PTR_WIDTH  (PTR_WIDTH)
    ) memory (
        .wclk     (wr_clk),
        .w_en     (wr_valid),
        .b_wptr   (b_wptr),
        .b_rptr   (b_rptr),
        .data_in  (wr_data),
        .full     (full),
        .data_out (rd_data)
    );

endmodule
