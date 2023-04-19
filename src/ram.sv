`default_nettype none

module ram
    #(int ADDR_SIZE = 11
    , int DATA_SIZE = 9
    )
    ( input  var clk
    , input  var [ADDR_SIZE-1:0] r_addr
    , input  var [ADDR_SIZE-1:0] w_addr
    , input  var wren
    , output var [DATA_SIZE-1:0] data_in
    , output var [DATA_SIZE-1:0] data_out
    );

    logic [DATA_SIZE-1:0] mem[2 ** ADDR_SIZE];

    always_ff @(posedge clk) begin
        data_out <= mem[r_addr];
        if (wren)
            mem[w_addr] <= data_in;
    end

endmodule
