IVERILOG ?= iverilog
VVP      ?= vvp
VERILATOR ?= verilator
YOSYS     ?= yosys
VIVADO    ?= vivado

TOP       ?= itch_parser
PART      ?=
PERIOD_NS ?= 10.000

BUILD_DIR := build
SIM_DIR   := $(BUILD_DIR)/itch
WAVE_DIR  := $(BUILD_DIR)/waves/itch
RTL_DIR   := rtl/itch
EVENT_RTL_DIR := rtl/event_fifo
TB_DIR    := tb/itch
IVFLAGS   := -g2012 -Wall -I. -I$(RTL_DIR)
SYS_DEFS := rtl/sys_defs_pkg.sv
RTL_SOURCES := $(RTL_DIR)/itch_event_pkg.sv \
	$(RTL_DIR)/itch_parser_add.sv \
	$(RTL_DIR)/itch_parser_execute.sv \
	$(RTL_DIR)/itch_parser_cancel.sv \
	$(RTL_DIR)/itch_parser_delete.sv \
	$(RTL_DIR)/itch_parser_replace.sv \
	$(RTL_DIR)/itch_parser.sv
EVENT_FIFO_SOURCES := $(EVENT_RTL_DIR)/wptr_handler.sv \
	$(EVENT_RTL_DIR)/rptr_handler.sv \
	$(EVENT_RTL_DIR)/fifo_mem.sv \
	$(EVENT_RTL_DIR)/event_fifo.sv
PIPELINE_SOURCES := $(SYS_DEFS) \
	$(RTL_SOURCES) \
	$(EVENT_FIFO_SOURCES) \
	rtl/itch_pipeline.sv

.PHONY: all test test-add test-router test-event-fifo test-pipeline lint synth-yosys timing-vivado clean

all: test-add test-router test-event-fifo test-pipeline

test: all

$(SIM_DIR) $(WAVE_DIR):
	mkdir -p $@

test-add: $(SIM_DIR) $(WAVE_DIR)
	$(IVERILOG) $(IVFLAGS) -s itch_parser_add_tb \
		-o $(SIM_DIR)/itch_parser_add_tb.vvp \
		$(RTL_DIR)/itch_event_pkg.sv \
		$(RTL_DIR)/itch_parser_add.sv \
		$(TB_DIR)/itch_parser_add_tb.sv
	$(VVP) $(SIM_DIR)/itch_parser_add_tb.vvp +VCD=$(WAVE_DIR)/itch_parser_add_tb.vcd

test-router: $(SIM_DIR) $(WAVE_DIR)
	$(IVERILOG) $(IVFLAGS) -s itch_parser_tb \
		-o $(SIM_DIR)/itch_parser_tb.vvp \
		$(RTL_SOURCES) \
		$(TB_DIR)/itch_parser_tb.sv
	$(VVP) $(SIM_DIR)/itch_parser_tb.vvp +VCD=$(WAVE_DIR)/itch_parser_tb.vcd

test-event-fifo: $(SIM_DIR) $(WAVE_DIR)
	$(IVERILOG) $(IVFLAGS) -s event_fifo_tb \
		-o $(SIM_DIR)/event_fifo_tb.vvp \
		$(RTL_DIR)/itch_event_pkg.sv \
		$(EVENT_FIFO_SOURCES) \
		$(TB_DIR)/event_fifo_tb.sv
	$(VVP) $(SIM_DIR)/event_fifo_tb.vvp +VCD=$(WAVE_DIR)/event_fifo_tb.vcd

test-pipeline: $(SIM_DIR) $(WAVE_DIR)
	$(IVERILOG) $(IVFLAGS) -s itch_pipeline_tb \
		-o $(SIM_DIR)/itch_pipeline_tb.vvp \
		$(PIPELINE_SOURCES) \
		$(TB_DIR)/itch_pipeline_tb.sv
	$(VVP) $(SIM_DIR)/itch_pipeline_tb.vvp +VCD=$(WAVE_DIR)/itch_pipeline_tb.vcd

lint:
	$(VERILATOR) --lint-only --sv -Wall -Wno-fatal \
		-Wno-EOFNEWLINE -Wno-UNUSEDPARAM -Wno-WIDTHEXPAND \
		-I$(RTL_DIR) --top-module $(TOP) $(RTL_SOURCES)
	$(VERILATOR) --lint-only --sv -Wall -Wno-fatal \
		-Wno-EOFNEWLINE -Wno-UNUSEDPARAM -Wno-WIDTHEXPAND \
		-I$(RTL_DIR) --top-module event_fifo \
		$(RTL_DIR)/itch_event_pkg.sv $(EVENT_FIFO_SOURCES)
	$(VERILATOR) --lint-only --sv -Wall -Wno-fatal \
		-Wno-EOFNEWLINE -Wno-UNUSEDPARAM -Wno-WIDTHEXPAND \
		-I$(RTL_DIR) --top-module itch_pipeline $(PIPELINE_SOURCES)

synth-yosys:
	mkdir -p $(BUILD_DIR)/synth/yosys
	$(YOSYS) -l $(BUILD_DIR)/synth/yosys/synthesis.log -p \
		'read_verilog -sv -I$(RTL_DIR) $(PIPELINE_SOURCES); hierarchy -check -top $(TOP); synth -top $(TOP); stat'

timing-vivado:
	@test -n "$(PART)" || { \
		echo "error: set an exact FPGA part, for example: make timing-vivado PART=xc7a35tcsg324-1"; \
		exit 2; \
	}
	mkdir -p $(BUILD_DIR)/synth/vivado
	TOP=$(TOP) PART=$(PART) PERIOD_NS=$(PERIOD_NS) OUT_DIR=$(abspath $(BUILD_DIR)/synth/vivado) \
		$(VIVADO) -mode batch -nojournal -nolog -source scripts/vivado_timing.tcl

clean:
	rm -rf $(BUILD_DIR)
