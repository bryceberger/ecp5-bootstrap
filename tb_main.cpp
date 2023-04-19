#include <stdlib.h>
#include <verilated.h>
#include <verilated_fst_c.h>

#include <cstdio>
#include <cstdlib>
#include <iostream>

#include "Vmain.h"
#include "Vmain___024root.h"

#define MAX_SIM_TIME (1000)
auto sim_time = 0;

void step_fast(Vmain* dut, VerilatedFstC* trace) {
    dut->f_miso = rand() & 1;

    dut->clk ^= 1;
    dut->f_sclk ^= 1;
    dut->eval();
    trace->dump(sim_time);
    sim_time++;

    dut->clk ^= 1;
    dut->f_sclk ^= 1;
    dut->eval();
    trace->dump(sim_time);
    sim_time++;
}

void step(Vmain* dut, VerilatedFstC* trace) {
    auto delay = 7 + rand() % 4;
    for (int i = 0; i < delay; i++) {
        step_fast(dut, trace);
    }

    delay = 7 + rand() % 4;
    for (int i = 0; i < delay; i++) {
        step_fast(dut, trace);
    }
}

void reset(Vmain* dut, VerilatedFstC* trace) {
    dut->clk = 1;
    dut->f_sclk = 1;
    dut->rx = 1;
    dut->n_rst = 0;
    step_fast(dut, trace);
    for (int i = 0; i < 3; i++) {
        step_fast(dut, trace);
    }
    dut->n_rst = 1;
}

void send_packet(Vmain* dut, VerilatedFstC* trace, char packet) {
    // step_fast some random amount of time
    auto delay = 5 + rand() % 20;
    for (auto i = 0; i < delay; i++) {
        step_fast(dut, trace);
    }

    for (auto bit = 0; bit < 11; bit++) {
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

        step(dut, trace);
    }
}

int main(int argc, char** argv, char** env) {
    auto dut = new Vmain;

    Verilated::traceEverOn(true);
    auto m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("main.vcd");

    // char packets[] = "abcd";

    reset(dut, m_trace);

    // don't want to timeout before doing anything
    for (int i = 0; i < 10000; i++) {
        step(dut, m_trace);
    }

    for (auto i = 0; i < 512 + 100; i++) {
        send_packet(dut, m_trace, rand());
    }

    for (int i = 0; i < 300; i++) {
        step(dut, m_trace);
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
