module hex_dec
    ( input var en
    , input var [7:0] d
    , input var nibble_sel
    , input var [2:0] row_sel
    , input var [2:0] col_sel
    , output var pixel
    );

    logic [7:0] character;
    logic [63:0] pixels;
    font ft (.*);

    logic [3:0] nibble;
    assign nibble = nibble_sel ? d[7:4] : d[3:0];

    assign character = nibble <= 9 ? "0" + nibble : "A" + nibble - 10;

    assign pixel = en && pixels[~{row_sel, col_sel}];
endmodule
