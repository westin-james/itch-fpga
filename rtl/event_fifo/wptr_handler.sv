`timescale 1ns/1ps

module wptr_handler #(
    parameter int unsigned PTR_WIDTH = 3
) (
    input logic wclk,
    input logic wrst,
    input logic w_en,
    input logic [PTR_WIDTH-1:0] g_rptr_sync,
    output logic [PTR_WIDTH-1:0] b_wptr,
    output logic [PTR_WIDTH-1:0] g_wptr,
    output logic full
);

    logic [PTR_WIDTH-1:0] b_wptr_next;
    logic [PTR_WIDTH-1:0] g_wptr_next;
    logic wfull;

    assign b_wptr_next = b_wptr + (w_en && !full);
    assign g_wptr_next = (b_wptr_next >> 1) ^ b_wptr_next;

    assign wfull = (g_wptr_next == {
        ~g_rptr_sync[PTR_WIDTH-1:PTR_WIDTH-2],
         g_rptr_sync[PTR_WIDTH-3:0]
    });

    always_ff @(posedge wclk) begin
        if (wrst) begin
            b_wptr <= '0;
            g_wptr <= '0;
            full <= 1'b0;
        end else begin
            b_wptr <= b_wptr_next;
            g_wptr <= g_wptr_next;
            full <= wfull;
        end
    end

endmodule
