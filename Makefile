IVERILOG ?= iverilog
VVP      ?= vvp
VERILATOR ?= verilator
YOSYS     ?= yosys
VIVADO    ?= vivado

TOP       ?= itch_parser
PART      ?=
PERIOD_NS ?= 10.000

BUILD_DIR := build
SIM_DIR   := $(BUILD_DIR)/sim
RTL_DIR   := rtl/event/itch
EVENT_RTL_DIR := rtl/event/event_fifo
MOLDUDP64_RTL_DIR := rtl/packet_rx/moldudp64
UDP_RTL_DIR := rtl/packet_rx/udp
IPV4_RTL_DIR := rtl/packet_rx/ipv4
ETHERNET_RTL_DIR := rtl/packet_rx/ethernet
TB_DIR    := tb/event/itch
EVENT_TB_DIR := tb/event/event_fifo
MOLDUDP64_TB_DIR := tb/packet_rx/moldudp64
UDP_TB_DIR := tb/packet_rx/udp
IPV4_TB_DIR := tb/packet_rx/ipv4
ETHERNET_TB_DIR := tb/packet_rx/ethernet
IVFLAGS   := -g2012 -Wall -I. -I$(RTL_DIR)
SYS_DEFS := rtl/common/sys_defs_pkg.sv
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
MOLDUDP64_SOURCES := $(MOLDUDP64_RTL_DIR)/moldudp64_pkg.sv \
	$(MOLDUDP64_RTL_DIR)/moldudp64_decoder.sv
UDP_SOURCES := $(UDP_RTL_DIR)/udp_pkg.sv \
	$(UDP_RTL_DIR)/udp_decoder.sv
IPV4_SOURCES := $(IPV4_RTL_DIR)/ipv4_pkg.sv \
	$(IPV4_RTL_DIR)/ipv4_decoder.sv
ETHERNET_SOURCES := $(ETHERNET_RTL_DIR)/ethernet_pkg.sv \
	$(ETHERNET_RTL_DIR)/ethernet_decoder.sv
PIPELINE_SOURCES := $(SYS_DEFS) \
	$(ETHERNET_SOURCES) \
	$(IPV4_SOURCES) \
	$(UDP_SOURCES) \
	$(MOLDUDP64_SOURCES) \
	$(RTL_SOURCES) \
	$(EVENT_FIFO_SOURCES) \
	rtl/top/pipeline.sv
TEST_TARGETS := test-add test-router test-event-fifo test-ethernet test-ipv4 test-udp test-moldudp64 test-pipeline

.PHONY: all help test test-add test-router test-event-fifo test-ethernet test-ipv4 test-udp test-moldudp64 test-pipeline lint synth-yosys timing-vivado clean

all: test

help:
	@printf '%s\n' \
		'ITCH FPGA parser build targets:' \
		'' \
		'  make test             Run the complete simulation suite' \
		'  make test-add         Test the Add Order parser' \
		'  make test-router      Test ITCH message routing and parsers' \
		'  make test-event-fifo  Test the asynchronous event FIFO' \
		'  make test-ethernet    Test the Ethernet decoder' \
		'  make test-ipv4        Test the IPv4 decoder' \
		'  make test-udp         Test the UDP decoder' \
		'  make test-moldudp64   Test the MoldUDP64 decoder' \
		'  make test-pipeline    Test the integrated decoding pipeline' \
		'  make lint             Run Verilator lint checks' \
		'  make synth-yosys      Synthesize TOP with Yosys' \
		'  make timing-vivado    Run Vivado timing for PART' \
		'  make clean            Remove generated build artifacts' \
		'' \
		'Common options:' \
		'  TOP=<module>          Select synthesis top (default: itch_parser)' \
		'  PART=<part>           Set the FPGA part for timing-vivado' \
		'  PERIOD_NS=<ns>        Set the timing target (default: 10.000)' \
		'  IVERILOG=<path>       Override a build tool (also VVP, VERILATOR,' \
		'                       YOSYS, and VIVADO)'

test: | $(SIM_DIR)
	@passed=""; failed=""; \
	for target in $(TEST_TARGETS); do \
		if $(MAKE) --no-print-directory $$target 2>/dev/null; then \
			passed="$$passed $$target"; \
		else \
			failed="$$failed $$target"; \
		fi; \
	done; \
	printf '\nTest summary\n'; \
	for target in $$passed; do printf '  PASSED  %s\n' "$$target"; done; \
	for target in $$failed; do printf '  FAILED  %s\n' "$$target"; done; \
	if [ -n "$$failed" ]; then \
		printf '\nRESULT: FAILED\n'; \
		exit 1; \
	fi; \
	printf '\nRESULT: PASSED\n'

$(SIM_DIR):
	mkdir -p $@

define RUN_SIM
	@out="$(SIM_DIR)/$(1)"; \
	mkdir -p "$$out"; \
	log="$$out/run.log"; \
	if { \
		$(IVERILOG) $(IVFLAGS) -s $(2) \
			-o "$$out/$(2).vvp" $(3) && \
		$(VVP) "$$out/$(2).vvp" +VCD="$$out/$(2).vcd"; \
	} >"$$log" 2>&1; then \
		printf '  PASSED  %-18s %s\n' "$(1)" "$$log"; \
	else \
		status=$$?; \
		printf '  FAILED  %-18s %s\n' "$(1)" "$$log"; \
		sed 's/^/    /' "$$log"; \
		exit $$status; \
	fi
endef

test-add: | $(SIM_DIR)
	$(call RUN_SIM,$@,itch_parser_add_tb,\
		$(RTL_DIR)/itch_event_pkg.sv \
		$(RTL_DIR)/itch_parser_add.sv \
		$(TB_DIR)/itch_parser_add_tb.sv)

test-router: | $(SIM_DIR)
	$(call RUN_SIM,$@,itch_parser_tb,\
		$(RTL_SOURCES) \
		$(TB_DIR)/itch_parser_tb.sv)

test-event-fifo: | $(SIM_DIR)
	$(call RUN_SIM,$@,event_fifo_tb,\
		$(RTL_DIR)/itch_event_pkg.sv \
		$(EVENT_FIFO_SOURCES) \
		$(EVENT_TB_DIR)/event_fifo_tb.sv)

test-moldudp64: | $(SIM_DIR)
	$(call RUN_SIM,$@,moldudp64_decoder_tb,\
		$(MOLDUDP64_SOURCES) \
		$(MOLDUDP64_TB_DIR)/moldudp64_decoder_tb.sv)

test-udp: | $(SIM_DIR)
	$(call RUN_SIM,$@,udp_decoder_tb,\
		$(UDP_SOURCES) \
		$(UDP_TB_DIR)/udp_decoder_tb.sv)

test-ipv4: | $(SIM_DIR)
	$(call RUN_SIM,$@,ipv4_decoder_tb,\
		$(IPV4_SOURCES) \
		$(IPV4_TB_DIR)/ipv4_decoder_tb.sv)

test-ethernet: | $(SIM_DIR)
	$(call RUN_SIM,$@,ethernet_decoder_tb,\
		$(ETHERNET_SOURCES) \
		$(ETHERNET_TB_DIR)/ethernet_decoder_tb.sv)

test-pipeline: | $(SIM_DIR)
	$(call RUN_SIM,$@,pipeline_tb,\
		$(PIPELINE_SOURCES) \
		tb/top/pipeline_tb.sv)

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
		-I$(RTL_DIR) --top-module pipeline $(PIPELINE_SOURCES)

synth-yosys:
	mkdir -p $(BUILD_DIR)/synth/yosys
	$(YOSYS) -l $(BUILD_DIR)/synth/yosys/synthesis.log -p \
		'read_verilog -sv -I$(RTL_DIR) $(PIPELINE_SOURCES); hierarchy -check -top $(TOP); synth -top $(TOP); stat'

timing-vivado:
	@test -n "$(PART)" || { \
		echo "error: set an exact FPGA part, for example: make timing-vivado PART=xc7a35tcsg324-1"; \
		exit 2; \
	}
	mkdir -p $(BUILD_DIR)/pnr/vivado
	TOP=$(TOP) PART=$(PART) PERIOD_NS=$(PERIOD_NS) OUT_DIR=$(abspath $(BUILD_DIR)/pnr/vivado) \
		$(VIVADO) -mode batch -nojournal -nolog -source scripts/vivado/timing.tcl

clean:
	rm -rf $(BUILD_DIR)
