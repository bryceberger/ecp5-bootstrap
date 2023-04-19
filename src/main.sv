`default_nettype none `timescale 1ns / 1ns

module main
    ( input var clk
    , input var n_rst
    // spi
    , output var f_sclk
    , output var f_cs
    , output var f_mosi
    , input  var f_miso
    , output var f_done
    // uart
    , input  var rx
    , output var tx
    );

    spi spi (.*);
endmodule
