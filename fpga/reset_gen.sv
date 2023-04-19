`default_nettype none

module reset_gen
    ( input var clk
    , input var [1:0] lock
    , output var n_rst
    );

    wire locked = &lock;

    logic [2:0] count = 0;
    always_ff @(posedge clk, negedge locked)
        if (!locked)
            count <= 0;
        else
            count <= count == 3'b100 ? 3'b100 : count + 1;

    assign n_rst = count[2];
endmodule
