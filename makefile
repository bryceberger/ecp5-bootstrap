SHELL=/usr/bin/env bash -O globstar -O nullglob -c

source := $(shell find -name '*.sv')
hex := $(shell find -name '*.hex')
pinmap := $(shell find -name '*.lpf')

.PHONY: clean

cram: build/build.bit
	openFPGALoader -c jlink-plus build/build.bit

build/build.bit: build/build.svf build/build.config
	ecppack --svf build/build.svf build/build.config build/build.bit

build/build.svf build/build.config: build/build.json $(pinmap)
	nextpnr-ecp5 \
		--12k --package CABGA256 \
		--speed 6 --freq 5 \
		--json build/build.json --textcfg build/build.config --lpf fpga/pinmap.lpf \
		--lpf-allow-unconstrained

build/build.json: $(source) $(hex)
	mkdir -p build
	yosys -p "synth_ecp5 -top top -json build/build.json" **/*.sv

clean:
	rm -rf build
