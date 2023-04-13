module palette (
    input var [5:0] color,
    output var [8:0] rgb,
    input var active = 1
);
    logic [8:0] colors[63:0];
    initial
        $readmemh("palette.hex", colors);
    assign rgb = active ? colors[color] : 0;
endmodule
