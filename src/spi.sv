`default_nettype none

module spi (
    // internal communication
    input var clk,
    input var n_rst,
    output var [7:0] data,
    output var load,
    // actual pinout
    output var f_sclk,
    output var f_cs,
    output var f_mosi,
    input var f_miso
);
    wire [7:0] read_opcode = 'h45;

    wire [23:0] read_address = 'h400015;

    assign f_sclk = clk;

    typedef enum logic [5:0] {
        RESET,
        SEND_READ_OPCODE,
        SEND_READ_ADDRESS,
        READING,
        GIVE_DATA,
        DONE
    } state_t;
    state_t state, state_n;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst) state <= RESET;
        else state <= state_n;

    localparam int COUNT_BITS = 8;
    logic count_en, count_clear, rollover_flag;
    logic [COUNT_BITS-1:0] rollover_val, count;
    counter #(
        .NUM_BITS(COUNT_BITS)
    ) counter (
        .en(count_en),
        .clear(count_clear),
        .*
    );

    always_comb
        case (state)
            RESET: state_n = SEND_READ_OPCODE;

            SEND_READ_OPCODE:
            if (rollover_flag) state_n = SEND_READ_ADDRESS;
            else state_n = SEND_READ_OPCODE;

            SEND_READ_ADDRESS:
            if (rollover_flag) state_n = READING;
            else state_n = SEND_READ_ADDRESS;

            READING:
            if (rollover_flag) state_n = GIVE_DATA;
            else state_n = READING;

            GIVE_DATA: state_n = DONE;

            DONE: state_n = DONE;

            default: state_n = 'x;
        endcase

    always_comb
        case (state)
            SEND_READ_OPCODE: f_mosi = read_opcode[8 - count];

            SEND_READ_ADDRESS: f_mosi = read_address[24 - count];

            default: f_mosi = 1;
        endcase

    assign data = 'hbeef;
    always_comb
        case (state)
            GIVE_DATA: load = 1;
            default: load = 0;
        endcase

    assign count_clear = 0;
    always_comb
        case (state)
            SEND_READ_OPCODE: begin
                count_en = 1;
                rollover_val = 8;
            end

            SEND_READ_ADDRESS: begin
                count_en = 1;
                rollover_val = 24;
            end

            READING: begin
                count_en = 1;
                rollover_val = 64;
            end

            default: begin
                count_en = 0;
                rollover_val = 'x;
            end
        endcase
endmodule

module counter #(
    parameter int NUM_BITS
) (
    input var clk,
    input var n_rst,
    input var clear,
    input var en,
    input var [NUM_BITS-1:0] rollover_val,
    output var [NUM_BITS-1:0] count,
    output var rollover_flag
);
    logic [NUM_BITS-1:0] count_n;

    always_comb
        if (count == rollover_val) count_n = 1;
        else if (clear) count_n = 0;
        else count_n = count + 1;

    always_ff @(posedge clk, negedge n_rst)
        if (!n_rst) count <= 0;
        else if (en) count <= count_n;
        else count <= count;

    always_ff @(posedge clk)
        if (en) rollover_flag <= count == rollover_val - 1;
        else rollover_flag <= rollover_flag;

endmodule
