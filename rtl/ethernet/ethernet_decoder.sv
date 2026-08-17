`timescale 1ns/1ps

module ethernet_decoder (
    input logic clk,
    input logic reset,

    // Ethernet MAC frame stream
    // Starts at destination MAC byte 0
    // Preamble/SFD and FCS are assumed to be handled upstream
    input logic [7:0] data_in,
    input logic frame_valid,
    input logic frame_start,
    input logic frame_last,

    // Configured destination MAC address
    input logic [47:0] expected_dest_mac,

    // Ethernet payload stream
    output logic [7:0] data_out,
    output logic ethernet_payload_valid,
    output logic ethernet_payload_start,
    output logic ethernet_payload_last

);

    import ethernet_pkg::*;

    ethernet_state_t state;
    ethernet_state_t next_state;

    ethernet_pkt_header_t ethernet_pkt_header;

    logic [15:0] byte_count;

    logic packet_accepted;

    always_comb begin
        next_state = state;

        data_out = 8'd0;
        ethernet_payload_valid = 1'b0;
        ethernet_payload_start = 1'b0;
        ethernet_payload_last = 1'b0;

        // State transitions
        case (state)
            ETH_IDLE: begin
                if (frame_valid && frame_start) begin
                    if (frame_last)
                        next_state = ETH_IDLE;
                    else
                        next_state = ETH_HEADER;
                end
            end

            ETH_HEADER: begin
                if (frame_valid) begin

                    if (frame_last) begin
                        next_state = ETH_IDLE;
                    
                    end else if (byte_count == 6'd13) begin
                        next_state = ETH_PAYLOAD;
                    end
                end
            end

            ETH_PAYLOAD: begin
                if (frame_valid) begin
                    if (packet_accepted) begin
                        data_out = data_in;
                        ethernet_payload_valid = 1'b1;

                        ethernet_payload_start = (byte_count == 6'd14);
                        ethernet_payload_last = frame_last;
                    end

                    if (frame_last)
                        next_state = ETH_IDLE;
                end
            end

            default: begin
                next_state = ETH_IDLE;
            end

        endcase
    end


    always_ff @(posedge clk) begin
        if (reset) begin
            state <= ETH_IDLE;

            byte_count <= 16'd0;
            ethernet_pkt_header <= '0;
            packet_accepted <= 1'b0;

        end else begin
            state <= next_state;

            case (state)
                ETH_IDLE: begin
                    if (frame_valid && frame_start) begin
                        
                        // Start new ETH packet
                        packet_accepted <= 1'b0;

                        // Byte 0: Destination MAC [47:40]
                        ethernet_pkt_header.dest_mac <= {40'd0, data_in};

                        byte_count <= 16'd1;
                    end
                end

                ETH_HEADER: begin
                    if (frame_valid) begin
                        case (byte_count)
                            // Bytes 1-5: Destination MAC [39:0]
                            16'd1, 16'd2, 16'd3, 16'd4, 16'd5: 
                                ethernet_pkt_header.dest_mac <= {ethernet_pkt_header.dest_mac[39:0],data_in};

                            // Bytes 6-11: Source MAC [47:0]
                            16'd6, 16'd7, 16'd8, 16'd9, 16'd10, 16'd11: 
                                ethernet_pkt_header.source_mac <= {ethernet_pkt_header.source_mac[39:0],data_in};

                            // Bytes 12 & 13: EtherType [15:0]
                            16'd12: ethernet_pkt_header.ethertype[15:8] <= data_in;

                            // Byte 13: Separate for setting packet_accepted
                            16'd13: begin
                                ethernet_pkt_header.ethertype[7:0] <= data_in;

                                packet_accepted <=
                                    (ethernet_pkt_header.dest_mac == expected_dest_mac) &&
                                    ({ethernet_pkt_header.ethertype[15:8],data_in} == ETHERTYPE_IPV4);

                            end

                        endcase

                        byte_count <= byte_count + 1'b1;
                    end
                end

                ETH_PAYLOAD: begin
                    if (frame_valid)
                        byte_count <= byte_count + 1'b1;
                end

                default: begin
                end
            
            endcase
        end
    end

endmodule
