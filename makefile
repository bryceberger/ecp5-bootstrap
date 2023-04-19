# tb_source := tb.cpp
sim_source := $(shell find src -name '*.sv')
fpga_source := $(shell find fpga -name '*.sv')
v_source = $(shell find -name '*.v')

include_dir := include
include_source := $(shell find $(include_dir) -name '*.vh')

hex := $(shell find src -name '*.hex')
pinmap := $(shell find -name '*.lpf')

nproc := $(shell nproc)
WAVE = gtkwave --dark

.PHONY: clean clean_sim clean_cram %.sim cram
.PRECIOUS: obj_dir/V% obj_dir/%.vcd

cram: build/build.bit
	@openFPGALoader -c jlink-plus build/build.bit

build/build.bit: build/build.svf build/build.config
	@ecppack --svf build/build.svf build/build.config build/build.bit

build/build.svf build/build.config: build/build.json $(pinmap)
	@nextpnr-ecp5 \
		--12k --package CABGA256 \
		--speed 6 --freq 5 \
		--json build/build.json --textcfg build/build.config \
		--lpf fpga/pinmap.lpf --lpf-allow-unconstrained

build/build.json: $(fpga_source) $(hex) build/v
	@cp -u $(hex) build/verilog
	@yosys -p "synth_ecp5 -top top -json build/build.json" $(v_source) $(fpga_source)

build/v: $(sim_source) $(include_source)
	@mkdir -p build/verilog
	@sv2v --siloed -w adjacent -I$(include_dir) $(sim_source)
	@mv $(patsubst %.sv,%.v,$(sim_source)) build/verilog
	@touch build/v

%.sim: obj_dir/%.vcd
	@if ps -C "gtkwave" > /dev/null; \
		then \
		echo "gtkwave already running"; \
		else \
		$(WAVE) obj_dir/waveform.vcd > /dev/null 2>&1 & \
		fi

obj_dir/%.vcd: obj_dir/V%
	@obj_dir/Vspi
	@mv waveform.vcd obj_dir/$(patsubst %.vcd,%,$(@F)).vcd

obj_dir/V%: tb_%.cpp $(sim_source) $(include_source)
	@verilator -cc -O3 --trace --trace-fst --top-module $(patsubst V%,%,$(@F)) \
		--threads $(nproc) \
		-I$(include_dir) $(sim_source) --exe $<
	@make -C obj_dir -f Vspi.mk -s -j $(nproc) Vspi

clean: clean_cram clean_sim

clean_cram:
	@rm -rf build

clean_sim:
	@rm -rf obj_dir
