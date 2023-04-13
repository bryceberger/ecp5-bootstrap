`default_nettype none

module main (
    input var clk,
    input var vga_clk,
    input var n_rst,
    output var hsync,
    output var vsync,
    output var [2:0] red,
    output var [2:0] green,
    output var [2:0] blue
);
    logic [15:0] A, pc;
    logic rw;
    logic [7:0] d_in, d_out, cpu_d_in;

    // ===

    logic [7:0] color;
    logic [9:0] row, col;
    vga vga (
        .clk(vga_clk),
        .*
    );
    vga_driver vga_driver (
        .clk(clk),
        .*
    );
endmodule

module vga_driver (
    input var clk,
    input var n_rst,
    // VGA
    input var [9:0] row,
    input var [9:0] col,
    output var [7:0] color,
    // CPU
    input var rw,
    input var [15:0] pc,
    input var [15:0] A,
    input var [7:0] d_out,
    input var [7:0] cpu_d_in
);
    logic [7:0] d[8];
    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst) for (int i = 0; i < 8; i++) d[i] <= 0;
        else if (rw && A[15:3] == 13'h0800) d[A[2:0]] <= d_out;

    logic [3:0] region;

    logic [7:0] selected_data;
    always_comb
        casez (region)
            1: selected_data = d[{row[5:4], col[5]}];
            2: selected_data = clk ? 'h00 : 'hff;
            3: selected_data = ~col[5] ? pc[15:8] : pc[7:0];
            4: selected_data = ~col[5] ? A[15:8] : A[7:0];
            5: selected_data = d_out;
            6: selected_data = rw ? 'h00 : 'hff;
            7: selected_data = cpu_d_in;
            default: selected_data = 'x;
        endcase

    logic en, pixel;
    hex_dec hex_dec (
        .en,
        .d(selected_data),
        .nibble_sel(~col[4]),
        .row_sel(row[3:1]),
        .col_sel(col[3:1]),
        .pixel
    );

    always_comb
        casez ({
            row, col
        })
            {10'o02zz, 10'o01zz} : region = 1;  // mem
            {10'o015z, 10'o101z} : region = 2;  // clk
            {10'o020z, 10'o10zz} : region = 3;  // PC
            {10'o021z, 10'o10zz} : region = 3;
            {10'o024z, 10'o10zz} : region = 4;  // A
            {10'o025z, 10'o10zz} : region = 4;
            {10'o030z, 10'o100z} : region = 5;  // data
            {10'o031z, 10'o100z} : region = 5;
            {10'o030z, 10'o101z} : region = 5;
            {10'o031z, 10'o101z} : region = 5;
            {10'o030z, 10'o102z} : region = 5;
            {10'o031z, 10'o102z} : region = 5;
            {10'o030z, 10'o103z} : region = 5;
            {10'o031z, 10'o103z} : region = 5;
            {10'o031z, 10'o075z} : region = 6;  // rw
            {10'o034z, 10'o100z} : region = 7;  // CPU data
            {10'o035z, 10'o100z} : region = 7;
            {10'o034z, 10'o101z} : region = 7;
            {10'o035z, 10'o101z} : region = 7;
            {10'o034z, 10'o102z} : region = 7;
            {10'o035z, 10'o102z} : region = 7;
            {10'o034z, 10'o103z} : region = 7;
            {10'o035z, 10'o103z} : region = 7;
            default: region = 0;
        endcase

    assign en = |region;

    assign color = pixel ? 8'h30 : 8'h0f;
endmodule
