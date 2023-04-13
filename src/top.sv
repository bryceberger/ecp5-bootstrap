`default_nettype none

module top (
    output var hsync,
    output var vsync,
    output var [2:0] red,
    output var [2:0] green,
    output var [2:0] blue,
    output var [3:0] io
);
    wire osc_clk;  // goal: 50.35 MHz
    OSCG #(.DIV(2)) OSCinst0 (.OSC(osc_clk));

    wire [1:0] lock;
    wire filt_clk, pll_clk_1;
    EHXPLLL #(
        .CLKI_DIV(1),
        .CLKOP_DIV(2),
        .CLKOS_DIV(3)  // , .CLKFB_DIV()
    ) filt_pll (
        .CLKI(osc_clk),
        .ENCLKOP(1'b1),
        .CLKOP(pll_clk_1),
        .CLKFB(pll_clk_1),
        .ENCLKOS(1'b1),
        .CLKOS(filt_clk),
        .RST(1'b0),
        .STDBY(1'b0),
        .LOCK(lock[0])
    );

    wire pll_clk, clk, vga_clk;
    EHXPLLL #(
        .CLKI_DIV(1),
        .CLKOP_DIV(1),
        .CLKOS_DIV(4),
        .CLKOS2_DIV(56),
        .CLKOS3_DIV(2)
    ) pll (
        .CLKI(filt_clk),
        .ENCLKOP(1'b1),
        .CLKOP(pll_clk),
        .CLKFB(pll_clk),
        .ENCLKOS2(1'b1),
        .CLKOS2(clk),
        .ENCLKOS3(1'b1),
        .CLKOS3(vga_clk),
        .RST(1'b0),
        .STDBY(1'b0),
        .LOCK(lock[1])
    );

    wire n_rst;
    reset_gen reset_gen (.*);

    main main (.*);
endmodule
