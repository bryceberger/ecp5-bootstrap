module uart
    #(bit PARITY=0)
    // expect 1 MHz clk
    // 115.600 KHz data
    // => 9 clocks / data, resync on change
    // worst case has to change after ~86.5 us (9.6 samples / 10 bits)
    // so we shouldn't lose bits
    ( input  var clk
    , input  var n_rst
    , input  var rx
    , output var tx
    );

    logic [1:0] rx_sync;
    always_ff @(posedge clk)
        rx_sync <= {rx_sync[0], rx};

    wire rx_edge = rx_sync[1] != rx_sync[0];

    localparam int COUNT_BITS = 4;
    logic count_clear, count_en;
    logic [COUNT_BITS-1:0] count;
    counter
        #(.NUM_BITS(COUNT_BITS)
        ) counter
        ( .en(count_en)
        , .clear(count_clear)
        , .rollover_val('d10)
        , .*
        );

endmodule
