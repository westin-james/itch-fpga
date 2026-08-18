`timescale 1ns/1ps

module moldudp64_decoder (
    input logic clk,
    input logic reset,

    // UDP payload stream
    input logic [7:0] data_in,
    input logic udp_payload_valid,
    input logic udp_payload_start,
    input logic udp_payload_last,

    // ITCH message stream
    output logic [7:0] data_out,
    output logic itch_msg_valid,
    output logic itch_msg_start,
    output logic itch_msg_last,
    output logic [15:0] itch_msg_length
);

    import moldudp64_pkg::*;

    state_t state;
    state_t next_state;

    logic [4:0] header_byte_count;
    logic msg_len_byte_count;
    logic [15:0] msg_byte_count;
    logic [15:0] msg_len;

    logic [15:0] message_count;

    always_comb begin
        next_state = state;

        data_out = 8'd0;
        itch_msg_valid = 1'b0;
        itch_msg_start = 1'b0;
        itch_msg_last = 1'b0;
        itch_msg_length = msg_len;

        case (state)
            MOLD_IDLE: begin
                if (udp_payload_valid && udp_payload_start)
                    next_state = MOLD_HEADER;
            end

            MOLD_HEADER: begin
                if (udp_payload_valid && header_byte_count == 5'd19)
                    if ({message_count[15:8], data_in} == MOLD_HEARTBEAT_COUNT ||
                        {message_count[15:8], data_in} == MOLD_EOS_COUNT)
                        next_state = MOLD_IDLE;
                    else
                        next_state = MOLD_MSG_LENGTH;
            end

            MOLD_MSG_LENGTH: begin
                if (udp_payload_valid && msg_len_byte_count == 1'b1) begin
                    if ({msg_len[15:8], data_in} == 16'd0)
                        if (udp_payload_last)
                            next_state = MOLD_IDLE;
                        else
                            next_state = MOLD_MSG_LENGTH;
                    else    
                        next_state = MOLD_MSG_DATA;
                end
            end

            MOLD_MSG_DATA: begin
                if (udp_payload_valid) begin

                    data_out = data_in;
                    itch_msg_valid = 1'b1;

                    itch_msg_start = (msg_byte_count == 16'd1);
                    itch_msg_last = (msg_byte_count == msg_len);

                    if (msg_byte_count == msg_len) begin
                        if (udp_payload_last)
                            next_state = MOLD_IDLE;
                        else
                            next_state = MOLD_MSG_LENGTH;
                    end
                end
            end

            default: begin
                next_state = MOLD_IDLE;
            end

        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= MOLD_IDLE;

            header_byte_count <= 5'd0;

            msg_len_byte_count <= 1'b0;
            msg_byte_count <= 16'd0;
            msg_len <= 16'd0;

            message_count <= 16'd0;

        end else begin
            state <= next_state;

            case (state)
                MOLD_IDLE: begin
                    if (udp_payload_valid && udp_payload_start) begin
                        header_byte_count <= 5'd1;
                        message_count <= 16'd0;
                    end
                end

                MOLD_HEADER: begin
                    if (udp_payload_valid) begin
                        if (header_byte_count == 5'd18)
                            message_count[15:8] <= data_in;

                        if (header_byte_count == 5'd19)
                            message_count[7:0] <= data_in;

                        header_byte_count <= header_byte_count + 1'b1;
                    end
                end

                MOLD_MSG_LENGTH: begin
                    if (udp_payload_valid) begin
                        if (msg_len_byte_count == 1'b0) begin
                            msg_len[15:8] <= data_in;
                            msg_len_byte_count <= 1'b1;

                        end else begin
                            msg_len[7:0] <= data_in;
                            msg_len_byte_count <= 1'b0;

                            msg_byte_count <= 16'd1;
                        end
                    end
                end

                MOLD_MSG_DATA: begin
                    if (udp_payload_valid)
                        msg_byte_count <= msg_byte_count + 1'b1;
                end

                default: begin
                end
            
            endcase
        end
    end

endmodule
