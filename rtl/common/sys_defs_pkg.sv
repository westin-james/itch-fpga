`timescale 1ns/1ps

package sys_defs_pkg;

    // Number of normalized ITCH events buffered between the parser and
    // downstream event consumer.
    //
    // Constraints: power of two, minimum 4.
    // Consumed by: itch_pipeline -> event_fifo.
    parameter int unsigned EVENT_FIFO_DEPTH = 16;

endpackage
