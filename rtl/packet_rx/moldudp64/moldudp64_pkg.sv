`timescale 1ns/1ps

package moldudp64_pkg;

    // NASDAQ MoldUDP64 Packet Header definition (UNUSED)
    typedef struct packed {
        logic [79:0] session;
        logic [63:0] sequence_number;
        logic [15:0] message_count;
    } moldudp64_pkt_header_t;

    // Heartbeat;
    // packet sent once per second with next sequence number
    // message count of zero
    localparam logic [15:0] MOLD_HEARTBEAT_COUNT = 16'h0000;

    // End of Session
    // packets sent with message count of 0xFFFF instead of heartbeats
    localparam logic [15:0] MOLD_EOS_COUNT       = 16'hFFFF;

    

    // NASDAQ MoldUDP64 Request Packet definition
    // TODO? do i care about this

    // MoldUDP64 State Machine
    typedef enum logic [1:0] {
        MOLD_IDLE,
        MOLD_HEADER,
        MOLD_MSG_LENGTH,
        MOLD_MSG_DATA
    } state_t;

endpackage