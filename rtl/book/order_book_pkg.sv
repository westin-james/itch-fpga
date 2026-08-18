package order_book_pkg;

    typedef enum logic [2:0] {
        EVENT_NONE,
        EVENT_ADD,
        EVENT_EXECUTE,
        EVENT_CANCEL,
        EVENT_DELETE
    } event_type_t;

    typedef struct packed {
        event_type_t        event_type;

        logic [63:0]        order_id;
        logic               side;

        logic [31:0]        price;
        logic [31:0]        quantity;
    } book_event_t;

    typedef struct packed {
        logic               valid;

        logic [63:0]        order_id;
        logic               side;
        logic [31:0]        price;
        logic [31:0]        quantity;
    } order_entry_t;

endpackage