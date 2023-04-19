`default_nettype none `timescale 1ns / 1ns

module spi
    // internal communication
    ( input var clk
    , input var n_rst
    , output var [7:0] data_in
    , output var [7:0] addr
    , output var load
    // actual pinout
    , output var f_sclk
    , output var f_cs
    , output var f_mosi
    , input var f_miso
    // disable when done
    , output var f_done
    , output var spi_done
    );
    localparam byte READ = 'h03;
    localparam byte WRITE = 'h02;
    localparam byte WREN = 'h06;
    // status register:
    //   0 -> write in progress
    //   1 -> write enable
    // 2:5 -> block protection
    //   6 -> quad enable
    //   7 -> status register write disable
    localparam byte READ_STATUS = 'h05;
    localparam byte CHIP_ERASE = 'h60;

    assign f_sclk = clk;

    typedef enum logic [5:0]
        { RESET
        , DONE
        , DO_THING
        , TRANSITION
        , UNKNOWN = 'x
        } state_t;
    state_t state, state_n;

    assign spi_done = state == DONE;
    always_comb
        case (state)
            DONE: f_done = 1;
            default: f_done = 0;
        endcase

    localparam int COUNT_BITS = 8;
    logic count_en, count_clear, rollover_flag;
    logic [COUNT_BITS-1:0] rollover_val, count;

    counter
    #(.NUM_BITS(COUNT_BITS)
    ) counter
    ( .clk(~f_sclk)
    , .en(count_en)
    , .clear(count_clear)
    , .*
    );

    logic done;
    typedef struct packed {
        bit [7:0] cycles;
        // 8 bit instruction
        // 24 bit address
        // up to 32 bit data (arbitrary, can do up to 256 * 8 bits)
        bit [63:0] data;
    } inst_t;

    localparam int INST_COUNT = 14;
    inst_t instrs[INST_COUNT], inst;
    logic [$clog2(INST_COUNT):0] inst_count;

    assign instrs =
        { '{ cycles: 8
           , data: WREN
           }
        , '{ cycles: 8
           , data: CHIP_ERASE
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 64
           , data: {READ, 24'h000000, 32'hffffff}
           }
        , '{ cycles: 64
           , data: {WRITE, 24'h000000, 32'h8c25de89}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 16
           , data: {READ_STATUS, 8'hff}
           }
        , '{ cycles: 64
           , data: {READ, 24'h000000, 32'hffffff}
           }
        };
    assign inst = instrs[inst_count];

    always_ff @(negedge f_sclk, negedge n_rst)
        if (!n_rst)
            inst_count <= 0;
        else if (state == TRANSITION)
            inst_count <= inst_count + 1;
        else
            inst_count <= inst_count;

    assign done = inst_count == INST_COUNT - 1;

    always_ff @(negedge f_sclk, negedge n_rst)
        if (!n_rst)
            state <= RESET;
        else
            state <= state_n;

    always_comb
        case (state)
            RESET: state_n = DO_THING;

            DONE: state_n = DONE;

            DO_THING:
            if (rollover_flag) state_n = TRANSITION;
            else state_n = DO_THING;

            TRANSITION:
            if (done) state_n = DONE;
            else state_n = DO_THING;

            default: state_n = UNKNOWN;
        endcase

    always_comb
        case (state)
            DO_THING: f_mosi = inst.data[inst.cycles - count - 1];
            default: f_mosi = 1;
        endcase

    always_comb
        case (state)
            DO_THING: f_cs = 0;
            default: f_cs = 1;
        endcase

    always_ff @(negedge f_sclk, negedge n_rst)
        if (!n_rst) data_in <= 0;
        else data_in <= {data_in, f_miso};

    assign count_clear = 0;
    always_comb
        case (state)
            DO_THING: begin
                count_en = 1;
                rollover_val = inst.cycles;
            end

            default: begin
                count_en = 0;
                rollover_val = inst.cycles;
            end
        endcase
endmodule

module counter
    #(int NUM_BITS
    )
    ( input var clk
    , input var n_rst
    , input var clear
    , input var en
    , input var [NUM_BITS-1:0] rollover_val
    , output var [NUM_BITS-1:0] count
    , output var rollover_flag
    );

    logic [NUM_BITS-1:0] count_n;

    always_comb
        if (count >= rollover_val - 1)
            count_n = 0;
        else if (clear)
            count_n = 0;
        else
            count_n = count + 1;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst)
            count <= 0;
        else if (en)
            count <= count_n;
        else
            count <= count;

    assign rollover_flag = count >= rollover_val - 1;

endmodule
