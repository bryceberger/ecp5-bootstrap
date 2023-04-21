`default_nettype none `timescale 1ns / 1ns

module uart
    #(int NUM_PACKETS = 256
    )
    ( input  var clk
    , input  var n_rst
    // uart
    , input  var rx
    , output var tx
    // outputs to main
    , output var packet_en
    , output var [7:0] data
    , output var [$clog2(NUM_PACKETS)-1:0] packet_count
    , output var buffer_finish
    , output var timeout
    );

    logic [1:0] rx_sync;
    always_ff @(posedge clk)
        rx_sync <= {rx_sync[0], rx};

    wire rx_s = rx_sync[1];
    wire rx_edge = rx_sync[1] != rx_sync[0];
    wire rx_edge_fell = rx_sync[1] && !rx_sync[0];

    localparam int CLKS_PER_BIT = 35;
    localparam int SYNC_BITS = $clog2(CLKS_PER_BIT);
    logic sync_clear, sync_rollover;
    logic [SYNC_BITS-1:0] sync_count;
    counter
        #(.NUM_BITS(SYNC_BITS)
        ) sync_counter
        ( .en(1'b1)
        , .clear(rx_edge)
        , .rollover_val(CLKS_PER_BIT[SYNC_BITS-1:0])
        , .rollover_flag(sync_rollover)
        , .count(sync_count)
        , .*
        );

    // verilator lint_off WIDTHTRUNC
    localparam bit [SYNC_BITS-1:0] SYNC_HALF = CLKS_PER_BIT / 4;
    // verilator lint_on WIDTHTRUNC
    wire could_read_bit = sync_count == SYNC_HALF;
    logic read_bit;

    localparam int BITS_PER_PACKET = 10;
    localparam int BIT_BITS = $clog2(BITS_PER_PACKET + 2);
    logic bit_rollover, bit_clear, bit_en;
    logic [BIT_BITS-1:0] bit_count;
    counter
        #(.NUM_BITS(BIT_BITS)
        ) bit_counter
        ( .en(bit_en)
        , .clear(bit_clear)
        , .rollover_val(BITS_PER_PACKET[BIT_BITS-1:0] + 2)
        , .rollover_flag(bit_rollover)
        , .count(bit_count)
        , .*
        );

    assign packet_done = bit_rollover;

    logic [BITS_PER_PACKET-1:0] packet;
    assign data = packet[1+:8];
    always_ff @(posedge clk)
        if (read_bit)
            packet <= { rx_s
                      , packet[BITS_PER_PACKET-1:1]
                      };
        else
            packet <= packet;

    assign tx = 1;

    localparam int PACKET_BITS = $clog2(NUM_PACKETS);
    logic packet_done, packet_rollover;
    counter
        #(.NUM_BITS(PACKET_BITS)
        , .ROLLOVER_CORR(1)
        ) packet_counter
        ( .en(packet_en)
        , .clear(1'b0)
        , .rollover_val(NUM_PACKETS[PACKET_BITS-1:0])
        , .rollover_flag(packet_rollover)
        , .count(packet_count)
        , .*
        );

    // ~ 1 second timeout
    // localparam int TIMEOUT_MAX = 2 ** 20;
    // ~ 0.13 second timeout
    localparam int TIMEOUT_MAX = 2 ** 17;
    localparam int TIMEOUT_BITS = $clog2(TIMEOUT_MAX);
    logic timeout_en, timeout_clear, timeout_rollover;
    counter
        #(.NUM_BITS(TIMEOUT_BITS)
        ) timeout_counter
        ( .en(timeout_en)
        , .clear(timeout_clear)
        , .rollover_val(TIMEOUT_MAX[TIMEOUT_BITS-1:0])
        , .rollover_flag(timeout_rollover)
        , .count()
        , .*
        );

    typedef enum logic [3:0]
        { RESET
        , NONE
        , RECIEVE
        , PACKET_DONE
        , TIMEOUT
        , UNKNOWN = 'x
        } state_t;
    state_t state, state_n;

    assign timeout_en = state != RESET;
    assign timeout_clear = state != NONE;
    assign timeout = state == TIMEOUT;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst) state <= RESET;
        else state <= state_n;

    always_comb
        case (state)
            RESET:
            if (rx_edge_fell) state_n = RECIEVE;
            else state_n = RESET;

            NONE:
            if (rx_edge) state_n = RECIEVE;
            else if (timeout_rollover) state_n = TIMEOUT;
            else state_n = NONE;

            RECIEVE:
            if (packet_done) state_n = PACKET_DONE;
            else state_n = RECIEVE;

            PACKET_DONE: state_n = NONE;

            TIMEOUT: state_n = TIMEOUT;

            default: state_n = UNKNOWN;
        endcase

    always_comb
        case (state)
            RECIEVE: read_bit = could_read_bit;
            default: read_bit = 0;
        endcase

    always_comb
        case (state)
            NONE, RESET: begin 
                bit_clear = 1;
                bit_en = 1;
            end

            RECIEVE: begin
                bit_clear = 0;
                bit_en = read_bit;
            end

            default: begin
                bit_clear = 0;
                bit_en = 0;
            end
        endcase

    always_comb
        case (state)
            PACKET_DONE: packet_en = 1;
            default: packet_en = 0;
        endcase

    assign buffer_finish = (packet_rollover && packet_en);

endmodule
