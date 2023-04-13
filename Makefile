.PHONY: clean

cram: build/build.bit
	openFPGALoader -c jlink-plus build/build.bit

build/build.bit: build build/build.svf build/build.config
	ecppack --svf build/build.svf build/build.config build/build.bit

build/build.svf build/build.config: build build/build.json
	nextpnr-ecp5 \
		--12k --package CABGA256 \
		--speed 6 --freq 5 \
		--json build/build.json --textcfg build/build.config --lpf fpga/pinmap.lpf \
		--lpf-allow-unconstrained

build/build.json: build src/**.sv
	yosys -p "synth_ecp5 -top top -json build/build.json" src/**.sv

build:
	mkdir build

clean:
	rm -rf build
