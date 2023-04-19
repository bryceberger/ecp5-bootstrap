# tb_source := tb.cpp
sim_source := $(shell find src -name '*.sv')
fpga_source := $(shell find fpga -name '*.sv')
sv_source = $(shell find build -name '*.sv')

include_dir := include
include_source := $(shell find $(include_dir) -name '*.vh')

hex := $(shell find src -name '*.hex')
pinmap := $(shell find -name '*.lpf')

nproc := $(shell nproc)
WAVE = gtkwave --dark

BASE := $(MAKECMDGOALS:%.sim=%)

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

build/build.json: $(fpga_source) $(hex) build/sv
	# @cp -u $(hex) build/verilog
	@yosys -p "synth_ecp5 -top top -json build/build.json" $(sv_source) $(fpga_source)

# stupid yosys doesn't let you do '.*' in files that end with '.v'
# can't figure out how to force it to use systemverilog frontend
# so, just make all converted sv->v files have sv endings
build/sv: build/v
	@$(foreach ver,$(shell find build -name '*.v'), mv $(ver) $(ver:%.v=%.sv);)
	@touch build/sv

build/v: $(sim_source) $(include_source)
	@mkdir -p build/verilog
	@sv2v --siloed -w adjacent -I$(include_dir) $(sim_source)
	@mv $(sim_source:%.sv=%.v) build/verilog
	@touch build/v


%.sim: obj_dir/%.vcd
	@if ps -C "gtkwave" > /dev/null; \
		then \
		echo "gtkwave already running"; \
		else \
		$(WAVE) obj_dir/$(BASE).vcd > /dev/null 2>&1 & \
		fi

obj_dir/%.vcd: obj_dir/V%
	@obj_dir/V$(BASE)
	@mv $(BASE).vcd obj_dir/$(BASE).vcd

obj_dir/V%: tb_%.cpp $(sim_source) $(include_source)
	@verilator -cc -O3 --trace --trace-fst --top-module $(BASE) \
		--threads $(nproc) \
		-I$(include_dir) $(sim_source) --exe $<
	@make -C obj_dir -f V$(BASE).mk -s -j $(nproc) V$(BASE)

clean: clean_cram clean_sim

clean_cram:
	@rm -rf build

clean_sim:
	@rm -rf obj_dir
