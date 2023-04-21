`default_nettype none

module ram
    #(int ADDR_SIZE = 11
    , int DATA_SIZE = 9
    )
    ( input  var clk
    , input  var [ADDR_SIZE-1:0] addr
    , input  var wren
    , input  var [DATA_SIZE-1:0] data_in
    , output var [DATA_SIZE-1:0] data_out
    );

    logic [DATA_SIZE-1:0] mem[2 ** ADDR_SIZE];

    always_ff @(posedge clk) begin
        data_out <= mem[addr];
        if (wren)
            mem[addr] <= data_in;
    end

endmodule
