`timescale 1ns/1ps

package ethernet_pkg;

    localparam logic [15:0] ETHERTYPE_IPV4 = 16'h0800;

    typedef struct packed {
        logic [47:0] dest_mac;
        logic [47:0] source_mac;
        logic [15:0] ethertype;
    } ethernet_pkt_header_t;

    typedef enum logic [1:0] {
        ETH_IDLE,
        ETH_HEADER,
        ETH_PAYLOAD
    } ethernet_state_t;

endpackage