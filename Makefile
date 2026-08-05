IVERILOG ?= iverilog
VVP      ?= vvp

BUILD_DIR := build
SIM_DIR   := $(BUILD_DIR)/itch
WAVE_DIR  := $(BUILD_DIR)/waves/itch
RTL_DIR   := rtl/itch
TB_DIR    := tb/itch
IVFLAGS   := -g2012 -Wall -I. -I$(RTL_DIR)

.PHONY: all test-add test-router clean

all: test-add test-router

$(SIM_DIR) $(WAVE_DIR):
	mkdir -p $@

test-add: $(SIM_DIR) $(WAVE_DIR)
	$(IVERILOG) $(IVFLAGS) -s itch_parser_add_tb \
		-o $(SIM_DIR)/itch_parser_add_tb.vvp \
		$(RTL_DIR)/itch_parser_add.sv \
		$(TB_DIR)/itch_parser_add_tb.sv
	$(VVP) $(SIM_DIR)/itch_parser_add_tb.vvp +VCD=$(WAVE_DIR)/itch_parser_add_tb.vcd

test-router: $(SIM_DIR) $(WAVE_DIR)
	$(IVERILOG) $(IVFLAGS) -s itch_parser_tb \
		-o $(SIM_DIR)/itch_parser_tb.vvp \
		$(RTL_DIR)/itch_parser_add.sv \
		$(RTL_DIR)/itch_parser.sv \
		$(TB_DIR)/itch_parser_tb.sv
	$(VVP) $(SIM_DIR)/itch_parser_tb.vvp +VCD=$(WAVE_DIR)/itch_parser_tb.vcd

clean:
	rm -rf $(BUILD_DIR)
