module counter
    #(int NUM_BITS
    , bit [NUM_BITS-1:0] ROLLOVER_CORR = 2
    )
    ( input var clk
    , input var n_rst
    , input var clear
    , input var en
    , input var [NUM_BITS-1:0] rollover_val
    , output var [NUM_BITS-1:0] count
    , output var rollover_flag
    );

    logic [NUM_BITS-1:0] count_n;

    always_comb
        if (count >= rollover_val - 1)
            count_n = 0;
        else if (clear)
            count_n = 0;
        else
            count_n = count + 1;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst)
            count <= 0;
        else if (en)
            count <= count_n;
        else
            count <= count;

    always_ff @(posedge clk)
        rollover_flag <= count >= rollover_val - ROLLOVER_CORR;

endmodule
