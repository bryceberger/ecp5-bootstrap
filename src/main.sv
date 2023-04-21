`default_nettype none `timescale 1ns / 1ns

`include "spi.vh"

module main
    import spi_pkg::cmd_t;
    ( input var clk
    , input var n_rst
    // spi
    , input  var f_sclk
    , output var f_cs
    , output var f_mosi
    , input  var f_miso
    , output var f_done
    // uart
    , input  var rx
    , output var tx
    );

    localparam int BLOCK_SIZE = (8 * 256) / 8;
    localparam int BLOCK_BITS = $clog2(BLOCK_SIZE);

    cmd_t spi_cmd, spi_cmd_n;
    logic spi_done;
    logic [23:0] spi_addr_write, spi_addr_read;
    logic [7:0] spi_data_read;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst)
            spi_cmd <= spi_pkg::ERASE;
        else if (spi_done)
            spi_cmd <= spi_cmd_n;
        else
            spi_cmd <= spi_cmd;

    spi spi
        ( .cmd(spi_cmd)
        , .cmd_done(spi_done)
        , .addr_in(spi_addr_write)
        , .addr_out(spi_addr_read)
        , .data_in(spi_data_read)
        , .data_out() // data coming out of flash
        , .*
        );

    logic [BLOCK_BITS-1:0] uart_addr;
    logic [7:0] uart_data;
    logic uart_wren, uart_buffer_full, uart_timeout;
    uart
        #(.NUM_PACKETS(BLOCK_SIZE)
        ) uart
        ( .packet_en(uart_wren)
        , .data(uart_data)
        , .packet_count(uart_addr)
        , .buffer_finish(uart_buffer_full)
        , .timeout(uart_timeout)
        , .*
        );

    logic last_written = 0;

    always_comb
        if (uart_timeout && last_written)
            spi_cmd_n = spi_pkg::END;
        else if (uart_buffer_full || uart_timeout) 
            spi_cmd_n = spi_pkg::WRITE;
        else
            spi_cmd_n = spi_pkg::NONE;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst)
            last_written <= 0;
        else if (uart_timeout && spi_done)
            last_written <= 1;
        else
            last_written <= last_written;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst)
            spi_addr_write <= 0 - BLOCK_SIZE[23:0];
        else if (uart_buffer_full)
            spi_addr_write <= spi_addr_write + BLOCK_SIZE[23:0];
        else
            spi_addr_write <= spi_addr_write;

    logic uart_buffer;
    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst)
            uart_buffer <= 0;
        else if (uart_buffer_full)
            uart_buffer <= ~uart_buffer;
        else
            uart_buffer <= uart_buffer;


    logic [7:0] ram_out[2];
    assign spi_data_read = ram_out[~uart_buffer];
    logic [BLOCK_BITS-1:0] ram_addr[2];
    always_comb
        case (uart_buffer)
            0: begin
                ram_addr[0] = uart_addr;
                ram_addr[1] = spi_addr_read;
            end
            default: begin
                ram_addr[0] = spi_addr_read;
                ram_addr[1] = uart_addr;
            end
        endcase

    ram
        #(.ADDR_SIZE(BLOCK_BITS)
        , .DATA_SIZE(8)
        ) ram0
        ( .addr(ram_addr[0])
        , .wren(uart_buffer == 0 && uart_wren)
        , .data_in(uart_data)
        , .data_out(ram_out[0])
        , .*
        );
    ram
        #(.ADDR_SIZE(BLOCK_BITS)
        , .DATA_SIZE(8)
        ) ram1
        ( .addr(ram_addr[1])
        , .wren(uart_buffer == 1 && uart_wren)
        , .data_in(uart_data)
        , .data_out(ram_out[1])
        , .*
        );
endmodule
