#include <stdlib.h>
#include <verilated.h>
#include <verilated_fst_c.h>

#include <cstdio>
#include <iostream>

#include "Vspi.h"
#include "Vspi___024root.h"

#define MAX_SIM_TIME (1000)
auto sim_time = 0;

void step(Vspi* dut, VerilatedFstC* trace) {
    dut->clk ^= 1;
    dut->eval();
    trace->dump(sim_time);
}

int main(int argc, char** argv, char** env) {
    auto dut = new Vspi;

    Verilated::traceEverOn(true);
    auto m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    dut->clk = 1;
    dut->n_rst = 0;
    step(dut, m_trace);
    for (int i = 0; i < 3; i++) {
        sim_time++;
        step(dut, m_trace);
    }
    dut->n_rst = 1;

    auto max_sim_time = MAX_SIM_TIME;
    auto done = false;
    while (sim_time++ < max_sim_time) {
        step(dut, m_trace);
        if (dut->spi_done && !done) {
            done = true;
            max_sim_time = sim_time + 10;
        }
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}
