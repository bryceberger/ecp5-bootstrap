#include <stdlib.h>
#include <verilated.h>
#include <verilated_fst_c.h>

#include <cstdio>
#include <cstdlib>
#include <iostream>

#include "Vuart.h"
#include "Vuart___024root.h"

#define MAX_SIM_TIME (1000)
auto sim_time = 0;

void step(Vuart* dut, VerilatedFstC* trace) {
    dut->clk ^= 1;
    dut->eval();
    trace->dump(sim_time);
    sim_time++;

    dut->clk ^= 1;
    dut->eval();
    trace->dump(sim_time);
    sim_time++;
}

void reset(Vuart* dut, VerilatedFstC* trace) {
    dut->clk = 1;
    dut->rx = 1;
    dut->n_rst = 0;
    step(dut, trace);
    for (int i = 0; i < 3; i++) {
        step(dut, trace);
    }
    dut->n_rst = 1;
}

void send_packet(Vuart* dut, VerilatedFstC* trace, char packet) {
    // step some random amount of time
    auto delay = 8 + rand() % 8;
    for (auto i = 0; i < delay; i++) {
        step(dut, trace);
    }

    // loop:
    // - send bit
    // - wait 8 or 9 cycles (random)
    dut->packet_start = 1;
    for (auto bit = 0; bit < 11; bit++) {
        dut->bit_start = 1;
        if (bit == 0) {
            // start bit
            dut->rx = 0;
        } else if (bit == 9) {
            // parity bit
            dut->rx = 1;
        } else if (bit == 10) {
            // stop bit
            dut->rx = 1;
        } else {
            dut->rx = (packet >> (bit - 1)) & 1;
        }

        auto delay = 8 + rand() % 2;
        for (auto i = 0; i < delay; i++) {
            step(dut, trace);
            dut->packet_start = 0;
            dut->bit_start = 0;
        }
    }
}

int main(int argc, char** argv, char** env) {
    auto dut = new Vuart;

    Verilated::traceEverOn(true);
    auto m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    char packets[] = "abcd";

    reset(dut, m_trace);

    for (auto packet : packets) {
        send_packet(dut, m_trace, packet);
    }

    for (int i = 0; i < 10; i++) {
        step(dut, m_trace);
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
