`timescale 1ns/1ps

package udp_pkg;

    // UDP Packet Header definition
    typedef struct packed {
        logic [15:0] source_port;
        logic [15:0] dest_port;
        logic [15:0] length;
        logic [15:0] checksum;
    } udp_pkt_header_t;

    // UDP State Machine
    typedef enum logic [1:0] {
        UDP_IDLE,
        UDP_HEADER,
        UDP_PAYLOAD
    } state_t;

endpackage