`default_nettype none `timescale 1ns / 1ns

module uart
    #(int NUM_PACKETS = 2048
    )
    // expect 1 MHz clk
    // 115.600 KHz data
    // => 9 clocks / data, resync on change
    // worst case has to change after ~86.5 us (9.6 samples / 10 bits)
    // so we shouldn't lose bits
    ( input  var clk
    , input  var n_rst
    // uart
    , input  var rx
    , output var tx
    // outputs to main
    , output var packet_done
    , output var [7:0] data
    , output var [$clog2(NUM_PACKETS):0] packet_count
    // just for testbench clarity
    , input  var packet_start
    , input  var bit_start
    );

    assign tx = 1;

    logic [1:0] rx_sync;
    always_ff @(posedge clk)
        rx_sync <= {rx_sync[0], rx};

    wire rx_s = rx_sync[1];
    wire rx_edge = rx_sync[1] != rx_sync[0];

    localparam int CLKS_PER_BIT = 9;
    localparam int SYNC_BITS = $clog2(CLKS_PER_BIT);
    logic sync_clear, sync_rollover;
    logic [SYNC_BITS-1:0] sync_count;
    counter
        #(.NUM_BITS(SYNC_BITS)
        ) sync_counter
        ( .en(1)
        , .clear(rx_edge)
        , .rollover_val(CLKS_PER_BIT[SYNC_BITS-1:0])
        , .rollover_flag(sync_rollover)
        , .count(sync_count)
        , .*
        );

    // verilator lint_off WIDTHTRUNC
    localparam bit [SYNC_BITS-1:0] SYNC_HALF = CLKS_PER_BIT / 2;
    // verilator lint_on WIDTHTRUNC
    wire could_read_bit = sync_count == SYNC_HALF;
    logic read_bit;

    localparam int BITS_PER_PACKET = 11;
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

    typedef enum logic [3:0]
        { NONE
        , RECIEVE
        , UNKNOWN = 'x
        } state_t;
    state_t state, state_n;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst) state <= NONE;
        else state <= state_n;

    always_comb
        case (state)
            NONE:
            if (rx_edge) state_n = RECIEVE;
            else state_n = NONE;

            RECIEVE:
            if (packet_done) state_n = NONE;
            else state_n = RECIEVE;

            default: state_n = UNKNOWN;
        endcase

    always_comb
        case (state)
            RECIEVE: read_bit = could_read_bit;
            default: read_bit = 0;
        endcase

    always_comb
        case (state)
            NONE: begin 
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

endmodule
