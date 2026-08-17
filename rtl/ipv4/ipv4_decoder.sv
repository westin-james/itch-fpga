`timescale 1ns/1ps

module ipv4_decoder (
    input logic clk,
    input logic reset,

    // Ethernet payload stream
    input logic [7:0] data_in,
    input logic ethernet_payload_valid,
    input logic ethernet_payload_start,
    input logic ethernet_payload_last,

    // Configured IPv4 destination address
    input logic [31:0] expected_dest_ip,

    // IPv4 payload stream
    output logic [7:0] data_out,
    output logic ipv4_payload_valid,
    output logic ipv4_payload_start,
    output logic ipv4_payload_last

);

    import ipv4_pkg::*;

    ipv4_state_t state;
    ipv4_state_t next_state;

    ipv4_pkt_header_t ipv4_pkt_header;

    logic [15:0] byte_count;
    logic [5:0] header_length_bytes;

    logic packet_accepted;

    always_comb begin
        next_state = state;

        data_out = 8'd0;
        ipv4_payload_valid = 1'b0;
        ipv4_payload_start = 1'b0;
        ipv4_payload_last = 1'b0;

        // State transitions
        case (state)
            IPV4_IDLE: begin
                if (ethernet_payload_valid && ethernet_payload_start) begin
                    if (ethernet_payload_last)
                        next_state = IPV4_IDLE;
                    else
                        next_state = IPV4_HEADER;
                end
            end

            IPV4_HEADER: begin
                if (ethernet_payload_valid) begin

                    if (ethernet_payload_last) begin
                        next_state = IPV4_IDLE;

                    end else if (ipv4_pkt_header.ihl < IPV4_MIN_IHL) begin
                        next_state = IPV4_HEADER;
                    
                    end else if (byte_count == header_length_bytes - 6'd1) begin
                        next_state = IPV4_PAYLOAD;
                    end
                end
            end

            IPV4_PAYLOAD: begin
                if (ethernet_payload_valid) begin
                    if (packet_accepted && byte_count < ipv4_pkt_header.total_length) begin
                        data_out = data_in;
                        ipv4_payload_valid = 1'b1;

                        ipv4_payload_start = (byte_count == header_length_bytes);
                        ipv4_payload_last = (byte_count == ipv4_pkt_header.total_length - 16'd1) || ethernet_payload_last;
                    end

                    if (ethernet_payload_last)
                        next_state = IPV4_IDLE;
                end
            end

            default: begin
                next_state = IPV4_IDLE;
            end

        endcase
    end


    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IPV4_IDLE;

            byte_count <= 16'd0;
            ipv4_pkt_header <= '0;
            packet_accepted <= 1'b0;

        end else begin
            state <= next_state;

            case (state)
                IPV4_IDLE: begin
                    if (ethernet_payload_valid && ethernet_payload_start) begin
                        
                        // Start new IPV4 packet
                        packet_accepted <= 1'b0;

                        // Byte 0: version [7:4] and ihl [3:0]
                        ipv4_pkt_header.version <= data_in[7:4];
                        ipv4_pkt_header.ihl <= data_in[3:0];

                        byte_count <= 16'd1;
                    end
                end

                IPV4_HEADER: begin
                    if (ethernet_payload_valid) begin
                        case (byte_count)
                            // Byte 1: DSCP and ECN
                            16'd1: ipv4_pkt_header.dscp_ecn <= data_in;

                            // Bytes 2-3: Total Length
                            16'd2, 16'd3: ipv4_pkt_header.total_length <= {ipv4_pkt_header.total_length[7:0],data_in};
                            
                            // Bytes 4-5: Identification
                            16'd4, 16'd5: ipv4_pkt_header.identification <= {ipv4_pkt_header.identification[7:0],data_in};

                            // Bytes 6-7: Flags & Fragment Offset
                            16'd6, 16'd7: ipv4_pkt_header.flags_fragment <= {ipv4_pkt_header.flags_fragment[7:0],data_in};

                            // Byte 8: Time to Live
                            16'd8: ipv4_pkt_header.time_to_live <= data_in;

                            // Byte 9: Protocol
                            16'd9: ipv4_pkt_header.protocol <= data_in;

                            // Bytes 10-11: Header Checksum
                            16'd10, 16'd11: ipv4_pkt_header.header_checksum <= {ipv4_pkt_header.header_checksum[7:0],data_in};

                            // Bytes 12-15: Source Address
                            16'd12, 16'd13, 16'd14, 16'd15: ipv4_pkt_header.source_addr <= {ipv4_pkt_header.source_addr[23:0],data_in};

                            // Bytes 16-19: Destination Address
                            16'd16, 16'd17, 16'd18: ipv4_pkt_header.dest_addr <= {ipv4_pkt_header.dest_addr[23:0],data_in};

                            // Byte 19: Separate for setting packet_accepted
                            16'd19: begin
                                ipv4_pkt_header.dest_addr <= {ipv4_pkt_header.dest_addr[23:0], data_in};

                                packet_accepted <=
                                    (ipv4_pkt_header.version == IPV4_VERSION) &&
                                    (ipv4_pkt_header.ihl >= IPV4_MIN_IHL) &&
                                    (ipv4_pkt_header.protocol == IPV4_PROTOCOL_UDP) &&
                                    (ipv4_pkt_header.flags_fragment[13] == 1'b0) &&
                                    (ipv4_pkt_header.flags_fragment[12:0] == 13'd0) &&
                                    ({ipv4_pkt_header.dest_addr[23:0], data_in} == expected_dest_ip) &&
                                    (ipv4_pkt_header.total_length >= header_length_bytes);

                            end

                        endcase

                        byte_count <= byte_count + 1'b1;
                    end
                end

                IPV4_PAYLOAD: begin
                    if (ethernet_payload_valid)
                        byte_count <= byte_count + 1'b1;
                end

                default: begin
                end
            
            endcase
        end
    end

    assign header_length_bytes = {ipv4_pkt_header.ihl, 2'b00};

endmodule
