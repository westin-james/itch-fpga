`timescale 1ns/1ps

module fifo_mem #(
    parameter int unsigned DEPTH = 8,
    parameter int unsigned DATA_WIDTH = 8,
    parameter int unsigned ADDR_WIDTH = $clog2(DEPTH),
    parameter int unsigned PTR_WIDTH = ADDR_WIDTH + 1
) (
    input logic wclk,
    input logic w_en,
    input logic [PTR_WIDTH-1:0] b_wptr,
    input logic [PTR_WIDTH-1:0] b_rptr,
    input logic [DATA_WIDTH-1:0] data_in,
    input logic full,
    output logic [DATA_WIDTH-1:0] data_out
);

    logic [DATA_WIDTH-1:0] fifo [0:DEPTH-1];

    always_ff @(posedge wclk) begin
        if (w_en && !full)
            fifo[b_wptr[ADDR_WIDTH-1:0]] <= data_in;
    end

    assign data_out = fifo[b_rptr[ADDR_WIDTH-1:0]];

endmodule
