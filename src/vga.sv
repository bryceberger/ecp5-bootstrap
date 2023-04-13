`default_nettype none

module vga (
    input var clk,
    // to controller
    input var [7:0] color,
    output var [9:0] row,
    output var [9:0] col,
    // to VGA
    output var vsync,
    output var hsync,
    output var [2:0] red,
    output var [2:0] green,
    output var [2:0] blue
);
    logic [15:0] frame_count = 0;
    logic [9:0] line_count = 0;
    logic [9:0] pixel_count = 0;
    logic [2:0] intra_pixel = 0;

    wire end_of_pixel;
    assign end_of_pixel = intra_pixel == 1;
    always_ff @(posedge clk)
        if (end_of_pixel) intra_pixel <= 0;
        else intra_pixel <= intra_pixel + 1;

    wire end_of_line;
    assign end_of_line = pixel_count == 799 && end_of_pixel;
    always_ff @(posedge clk)
        if (end_of_pixel)
            pixel_count <= pixel_count == 799 ? 0 : pixel_count + 1;
        else pixel_count <= pixel_count;

    wire end_of_frame;
    assign end_of_frame = line_count == 524 && end_of_line;
    always_ff @(posedge clk)
        if (end_of_line) line_count <= line_count == 524 ? 0 : line_count + 1;
        else line_count <= line_count;

    always_ff @(posedge clk)
        if (end_of_frame) frame_count <= frame_count + 1;
        else frame_count <= frame_count;

    assign row = line_count;
    assign col = pixel_count;

    // ---

    assign vsync = ~(490 <= line_count && line_count < 492);
    assign hsync = ~(656 <= pixel_count && pixel_count < 752);
    wire in_screen = line_count < 480 && pixel_count < 640;

    // ---

    logic [8:0] rgb;
    palette pt (
        .color(color[5:0]),
        .rgb(rgb)
    );

    assign {red, green, blue} = in_screen ? rgb : 0;

endmodule
