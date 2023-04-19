`default_nettype none `timescale 1ns / 1ns

module main
    ( input var clk
    , input var n_rst
    // vga
    , input var vga_clk
    , output var hsync
    , output var vsync
    , output var [2:0] red
    , output var [2:0] green
    , output var [2:0] blue
    // spi
    , output var f_sclk
    , output var f_cs
    , output var f_mosi
    , input var f_miso
    , output var f_done
    );

    logic load;
    logic [7:0] addr;
    logic [7:0] data;
    vga_driver vga_driver (.*);

    spi spi
        ( .*
        , .data_in(data)
        , .spi_done()
        );
endmodule

module vga_driver
    ( input var clk
    , input var n_rst
    // vga hw
    , input var vga_clk
    , output var hsync
    , output var vsync
    , output var [2:0] red
    , output var [2:0] green
    , output var [2:0] blue
    // input data
    , input var load
    , input var [7:0] addr
    , input var [7:0] data
    );

    logic [7:0] color;
    logic [9:0] row, col;
    vga vga
        ( .clk(vga_clk)
        , .*
        );

    // ===
    logic [7:0] d[8];
    initial for (int i = 0; i < 8; i++) d[i] = 0;

    always_ff @(posedge clk)
        if (load) d[addr] <= data;
        else d[addr] <= d[addr];

    logic [3:0] region;

    logic [7:0] selected_data;
    always_comb
        casez (region)
            1: selected_data = d[{row[5:4], col[5]}];
            default: selected_data = 'x;
        endcase

    logic en, pixel;
    hex_dec hex_dec
        ( .en
        , .d(selected_data)
        , .nibble_sel(~col[4])
        , .row_sel(row[3:1])
        , .col_sel(col[3:1])
        , .pixel
        );

    always_comb
        casez ({
            row, col
        })
            {10'o02zz, 10'o01zz} : region = 1;  // mem
            default: region = 0;
        endcase

    assign en = |region;

    assign color = pixel ? 8'h30 : 8'h0f;
endmodule
