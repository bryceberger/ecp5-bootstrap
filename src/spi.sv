`default_nettype none `timescale 1ns / 1ns

`include "spi.vh"

module spi
    import spi_pkg::cmd_t;
    ( input  var clk
    , input  var n_rst
    // control signals
    , input  var cmd_t cmd
    , output var cmd_done
    , input  var [23:0] addr_in  // address to send to flash
    , output var [23:0] addr_out // address to request data from fpga
    , input  var [7:0] data_in   // data from fpga memory
    , output var [7:0] data_out  // data from flash
    // spi signals
    , output var f_cs
    , output var f_mosi
    , input  var f_miso
    , output var f_done // disables clock
    );

    localparam byte F_READ = 'h03;
    localparam byte F_WRITE = 'h02;
    localparam byte F_WREN = 'h06;
    // status register:
    //   0 -> write in progress
    //   1 -> write enable
    // 2:5 -> block protection
    //   6 -> quad enable
    //   7 -> status register write disable
    localparam byte F_READ_STATUS = 'h05;
    localparam byte F_CHIP_ERASE = 'h60;

    logic status_wren, status_write_done;
    assign status_wren = data_out[1];
    assign status_write_done = ~data_out[0];

    localparam int COUNT_BITS = $clog2(8 * 256 + 1);
    logic count_en, rollover_flag;
    logic [COUNT_BITS-1:0] rollover_val, count;
    counter
    #(.NUM_BITS(COUNT_BITS)
    ) counter
    ( .clk(~clk)
    , .en(count_en)
    , .clear(0)
    , .*
    );

    always_ff @(negedge clk, negedge n_rst)
        if (!n_rst) data_out <= 0;
        else if (!f_cs) data_out <= {data_out[6:0], f_miso};
        else data_out <= data_out;

    typedef enum logic [3:0]
        { NONE
        , WRITE_WREN
        , T_CHECK_WREN
        , CHECK_WREN
        , WAIT_WREN
        , SEND_WRITE
        , WRITE_DATA
        , ERASE
        , T_CHECK_WRITE_DONE
        , CHECK_WRITE_DONE
        , WAIT_WRITE_DONE
        , SEND_READ
        , READ
        , END
        , UNKNOWN = 'x
        } state_t;
    state_t state, state_n, state_r;
    logic transition;
    assign cmd_done = state == NONE;
    assign f_done = state == END || state == NONE;

    cmd_t cmd_reg;
    always_ff @(posedge clk)
        if (state == NONE)
            cmd_reg <= cmd;
        else
            cmd_reg <= cmd;

    wire [15:0] read_status_ext = {F_READ_STATUS, 8'hff};
    wire [31:0] write_ext = {F_WRITE, addr_in};
    wire [31:0] read_ext = {F_READ, addr_in};

    wire [2:0] idx_8 = 3'd7 - count[2:0];
    wire [3:0] idx_16 = 4'd15 - count[3:0];
    wire [4:0] idx_32 = 5'd31 - count[4:0];
    always_comb
        case (state)
            WRITE_WREN:       f_mosi = F_WREN[idx_8];
            CHECK_WREN:       f_mosi = read_status_ext[idx_16];
            SEND_WRITE:       f_mosi = write_ext[idx_32];
            WRITE_DATA:       f_mosi = data_in[idx_8];
            ERASE:            f_mosi = F_CHIP_ERASE[idx_8];
            CHECK_WRITE_DONE: f_mosi = read_status_ext[idx_16];
            SEND_READ:        f_mosi = read_ext[idx_32];
            default:          f_mosi = 1;
        endcase

    always_comb
        case (state)
            WRITE_DATA: addr_out = {12'h0, (count + 12'h1) >> 3};
            default: addr_out = 0;
        endcase

    always_ff @(negedge clk, negedge n_rst)
        if (!n_rst) state <= NONE;
        else if (transition) state <= state_n;
        else state <= state;

    always_ff @(negedge clk)
        state_r <= state;

    always_comb
        case (state)
            NONE: case (cmd)
                spi_pkg::READ:
                    state_n = SEND_READ;
                spi_pkg::WRITE, spi_pkg::ERASE:
                    state_n = WRITE_WREN;
                spi_pkg::END:
                    state_n = END;
                default:
                    state_n = NONE;
            endcase

            END: state_n = END;

            // set the wren latch
            WRITE_WREN: state_n = T_CHECK_WREN;
            // and loop until wren is enabled
            T_CHECK_WREN: state_n = CHECK_WREN;
            CHECK_WREN: state_n = WAIT_WREN;
            WAIT_WREN:
            if (status_wren)
                case (cmd_reg)
                    spi_pkg::WRITE: state_n = SEND_WRITE;
                    spi_pkg::ERASE: state_n = ERASE;
                    default: state_n = NONE;
                endcase
            else state_n = CHECK_WREN;

            // send write / erase command
            SEND_WRITE: state_n = WRITE_DATA;
            WRITE_DATA, ERASE: state_n = T_CHECK_WRITE_DONE;
            // and loop until it's done
            T_CHECK_WRITE_DONE: state_n = CHECK_WRITE_DONE;
            CHECK_WRITE_DONE: state_n = WAIT_WRITE_DONE;
            WAIT_WRITE_DONE:
            if (status_write_done) state_n = NONE;
            /* if (status_write_done) state_n = SEND_READ; */
            else state_n = CHECK_WRITE_DONE;

            SEND_READ: state_n = READ;
            READ: state_n = NONE;

            default: state_n = UNKNOWN;
        endcase

    always_comb
        case (state)
            WRITE_WREN, ERASE: begin
                count_en = 1;
                rollover_val = 8;
                transition = rollover_flag;
            end
            SEND_WRITE, SEND_READ: begin
                count_en = 1;
                rollover_val = 8 + 24;
                transition = rollover_flag;
            end
            CHECK_WREN, CHECK_WRITE_DONE: begin
                count_en = 1;
                rollover_val = 8 + 8;
                transition = rollover_flag;
            end
            // something something rollover flag registered
            WRITE_DATA: begin
                count_en = 1;
                rollover_val = 2048;
                transition = rollover_flag && state_r == state;
            end
            READ: begin
                count_en = 1;
                rollover_val = 8;
                transition = rollover_flag && state_r == state;
            end
            default: begin 
                count_en = 0;
                rollover_val = '1;
                transition = 1;
            end
        endcase

    always_comb
        case (state)
            READ
            , SEND_READ
            , ERASE
            , SEND_WRITE
            , WRITE_DATA
            , WRITE_WREN
            , CHECK_WREN
            , CHECK_WRITE_DONE:
                f_cs = 0;
            default: f_cs = 1;
        endcase
endmodule

module spi_test
    import spi_pkg::cmd_t;
    // internal communication
    ( input var clk
    , input var n_rst
    // actual pinout
    , output var f_sclk
    , output var f_cs
    , output var f_mosi
    , input var f_miso
    // disable when done
    , output var f_done
    );

    assign f_sclk = clk;

    typedef struct packed {
        cmd_t command;
        bit [23:0] addr;
    } inst_t;

    localparam int CMD_COUNT = 3;
    inst_t cmds[CMD_COUNT];
    logic [$clog2(CMD_COUNT)-1:0] cmd_count;
    logic cmd_done;

    assign cmds = 
        { '{ command: spi_pkg::WRITE
           , addr: '0
           }
        , '{ command: spi_pkg::READ
           , addr: 'd128
           }
        , '{ command: spi_pkg::END
           , addr: '0
           }
        };

    always_ff @(posedge f_sclk, negedge n_rst)
        if (!n_rst)
            cmd_count <= 0;
        else if (cmd_done && !f_done)
            cmd_count <= cmd_count + 1;
        else
            cmd_count <= cmd_count;

    cmd_t cmd;
    logic [7:0] data_in, data_out;
    logic [23:0] addr_in, addr_out;

    assign cmd = cmds[cmd_count].command;
    assign addr_in = cmds[cmd_count].addr;
    assign data_in = 'hfe;

    spi_control spi_control (.*);
endmodule
