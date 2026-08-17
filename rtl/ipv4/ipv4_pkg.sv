`timescale 1ns/1ps

package ipv4_pkg;

    // Check variables
    localparam logic [3:0] IPV4_VERSION = 4'd4;
    localparam logic [3:0] IPV4_MIN_IHL = 4'd5;
    localparam logic [7:0] IPV4_PROTOCOL_UDP = 8'd17;

    // IPv4 Packet Header definition
    typedef struct packed {
        logic [3:0]  version;
        logic [3:0]  ihl;
        logic [7:0]  dscp_ecn;
        logic [15:0] total_length;
        logic [15:0] identification;
        logic [15:0] flags_fragment;
        logic [7:0]  time_to_live;
        logic [7:0]  protocol;
        logic [15:0] header_checksum;
        logic [31:0] source_addr;
        logic [31:0] dest_addr;
    } ipv4_pkt_header_t;

    // flags[2] = Reserved
    // flags[1] = DF: Don't Fragment
    // flags[0] = MF: More Fragments

    // The checksum field is the 16 bit one's complement of the one's complement sum of all 16 bit words in the header. For purposes of computing the checksum, the value of the checksum field is zero.

    // IPv4 State Machine
    typedef enum logic [1:0] {
        IPV4_IDLE,
        IPV4_HEADER,
        IPV4_PAYLOAD
    } ipv4_state_t;

endpackage
