`timescale 1ns/1ps

module udp_decoder (
    input logic clk,
    input logic reset,

    // IPv4 payload stream
    input logic [7:0] data_in,
    input logic ipv4_payload_valid,
    input logic ipv4_payload_start,
    input logic ipv4_payload_last,
    input logic [15:0] expected_dest_port,

    // UDP payload stream
    output logic [7:0] data_out,
    output logic udp_payload_valid,
    output logic udp_payload_start,
    output logic udp_payload_last

);

    import udp_pkg::*;

    state_t state;
    state_t next_state;

    udp_pkt_header_t udp_pkt_header;

    logic [15:0] byte_count;
    logic packet_accepted;

    always_comb begin
        next_state = state;

        data_out = 8'd0;
        udp_payload_valid = 1'b0;
        udp_payload_start = 1'b0;
        udp_payload_last = 1'b0;

        // State transitions
        case (state)
            UDP_IDLE: begin
                if (ipv4_payload_valid && ipv4_payload_start) begin
                    if (ipv4_payload_last)
                        next_state = UDP_IDLE;
                    else
                        next_state = UDP_HEADER;
                end
            end

            UDP_HEADER: begin
                if (ipv4_payload_valid) begin

                    if (ipv4_payload_last) begin
                        next_state = UDP_IDLE;
                    
                    end else if (byte_count == 16'd7) begin
                        if (udp_pkt_header.length <= 16'd8)
                            next_state = UDP_IDLE;
                        else
                            next_state = UDP_PAYLOAD;
                    end
                end
            end

            UDP_PAYLOAD: begin
                if (ipv4_payload_valid) begin
                    if (packet_accepted && byte_count < udp_pkt_header.length) begin
                        data_out = data_in;
                        udp_payload_valid = 1'b1;

                        udp_payload_start = (byte_count == 16'd8);
                        udp_payload_last = (byte_count == udp_pkt_header.length - 1'b1) || ipv4_payload_last;
                    end

                    if (ipv4_payload_last)
                        next_state = UDP_IDLE;
                end
            end

            default: begin
                next_state = UDP_IDLE;
            end

        endcase
    end


    always_ff @(posedge clk) begin
        if (reset) begin
            state <= UDP_IDLE;

            byte_count <= 16'd0;
            udp_pkt_header <= '0;
            packet_accepted <= 1'b0;

        end else begin
            state <= next_state;

            case (state)
                UDP_IDLE: begin
                    if (ipv4_payload_valid && ipv4_payload_start) begin
                        
                        // Start new UDP packet
                        packet_accepted <= 1'b0;

                        // Byte 0: Source port [15:8]
                        udp_pkt_header.source_port[15:8] <= data_in;
                        udp_pkt_header.source_port[7:0]  <= 8'd0;
                        udp_pkt_header.dest_port         <= 16'd0;
                        udp_pkt_header.length            <= 16'd0;
                        udp_pkt_header.checksum          <= 16'd0;

                        byte_count <= 16'd1;
                    end
                end

                UDP_HEADER: begin
                    if (ipv4_payload_valid) begin

                        // Byte 1: Source port [7:0]
                        if (byte_count == 16'd1)
                            udp_pkt_header.source_port[7:0] <= data_in;

                        // Bytes 2 & 3: Destination port
                        if (byte_count == 16'd2)
                            udp_pkt_header.dest_port[15:8] <= data_in;

                        if (byte_count == 16'd3) begin
                            udp_pkt_header.dest_port[7:0] <= data_in;

                            // Compare dest port to expected
                            packet_accepted <= ({udp_pkt_header.dest_port[15:8], data_in} == expected_dest_port);
                        end

                        // Bytes 4 & 5: UDP length
                        if (byte_count == 16'd4) 
                            udp_pkt_header.length[15:8] <= data_in;

                        if (byte_count == 16'd5)
                            udp_pkt_header.length[7:0] <= data_in;

                        // Bytes 6 & 7: Checksum
                        if (byte_count == 16'd6) 
                            udp_pkt_header.checksum[15:8] <= data_in;

                        if (byte_count == 16'd7)
                            udp_pkt_header.checksum[7:0] <= data_in;

                        byte_count <= byte_count + 1'b1;
                    end
                end

                UDP_PAYLOAD: begin
                    if (ipv4_payload_valid)
                        byte_count <= byte_count + 1'b1;
                end

                default: begin
                end
            
            endcase
        end
    end

endmodule
