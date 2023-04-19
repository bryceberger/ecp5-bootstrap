module font 
    ( input var [7:0] character
    , output var [63:0] pixels
    );

    logic [63:0] font_spec[255:0];
    initial
        $readmemh("font.hex", font_spec);
    assign pixels = font_spec[character];
endmodule
