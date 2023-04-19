`default_nettype none

module top
    // spi
    ( output var f_cs
    , output var f_mosi
    , input  var f_miso
    // uart
    , input  var rx
    , output var tx
    );

    wire osc_clk;  // goal: 50.35 MHz
    OSCG #(.DIV(2)) OSCinst0 (.OSC(osc_clk));

    wire [1:0] lock;
    wire filt_clk, pll_clk_1;
    EHXPLLL
        #(.CLKI_DIV(1)
        , .CLKOP_DIV(2)
        , .CLKOS_DIV(3) // , .CLKFB_DIV()
        ) filt_pll
        ( .CLKI(osc_clk)
        , .ENCLKOP(1'b1), .CLKOP(pll_clk_1), .CLKFB(pll_clk_1)
        , .ENCLKOS(1'b1), .CLKOS(filt_clk)
        , .RST(1'b0), .STDBY(1'b0)
        , .LOCK(lock[0])
        );

    wire pll_clk, clk;
    EHXPLLL
        #(.CLKI_DIV(1)
        , .CLKOP_DIV(1)
        , .CLKOS_DIV(4)
        , .CLKOS2_DIV(52)
        ) pll
        ( .CLKI(filt_clk)
        , .ENCLKOP(1'b1), .CLKOP(pll_clk), .CLKFB(pll_clk)
        , .ENCLKOS2(1'b1), .CLKOS2(clk)
        , .RST(1'b0), .STDBY(1'b0)
        , .LOCK(lock[1])
        );

    logic f_sclk;
    logic f_done;
    USRMCLK spi_clk
        ( .USRMCLKI(f_sclk)
        , .USRMCLKTS(f_done)
        );

    wire n_rst;
    reset_gen reset_gen (.*);

    main main (.*);
endmodule
