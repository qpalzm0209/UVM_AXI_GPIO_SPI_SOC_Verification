SHELL := /bin/bash

SIM_DIR := sim
WAVE_DIR := wave
FCOV_OPT := assert

.PHONY: help all gpio spi smoke smoke-gpio smoke-spi fcov fcov-gpio fcov-spi summary clean distclean verdi-gpio verdi-spi verdi-fcov-gpio verdi-fcov-spi

help:
	@echo "Targets:"
	@echo "  make all             - run GPIO UVM and SPI UVM tests"
	@echo "  make gpio            - run GPIO UVM test"
	@echo "  make spi             - run SPI mirror UVM test"
	@echo "  make fcov            - run GPIO/SPI with functional coverage DB"
	@echo "  make fcov-gpio       - run GPIO functional coverage DB"
	@echo "  make fcov-spi        - run SPI functional coverage DB"
	@echo "  make summary         - print functional coverage scoreboard summary"
	@echo "  make clean           - remove generated sim build files only"
	@echo "  make distclean       - clean plus remove logs, FSDB, coverage DB"
	@echo "  make verdi-gpio      - open GPIO UVM FSDB waveform"
	@echo "  make verdi-spi       - open SPI UVM FSDB waveform"

all: gpio spi summary

gpio:
	@cd $(SIM_DIR) && ./run_gpio_uvm.sh

spi:
	@cd $(SIM_DIR) && ./run_spi_uvm.sh

fcov: fcov-gpio fcov-spi summary

fcov-gpio:
	@cd $(SIM_DIR) && rm -rf simv_gpio_fcov simv_gpio_fcov.daidir gpio_func.vdb csrc ucli.key gpio_fcov_compile.log gpio_fcov_sim.log novas.* verdiLog && rm -f ../wave/gpio_uvm.fsdb
	@cd $(SIM_DIR) && vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -ntb_opts uvm \
		-cm $(FCOV_OPT) -cm_dir gpio_func.vdb \
		-f filelist_gpio_uvm.f -o simv_gpio_fcov -l gpio_fcov_compile.log
	@cd $(SIM_DIR) && ./simv_gpio_fcov +UVM_NO_RELNOTES -cm $(FCOV_OPT) -cm_dir gpio_func.vdb -l gpio_fcov_sim.log

fcov-spi:
	@cd $(SIM_DIR) && rm -rf simv_spi_fcov simv_spi_fcov.daidir spi_func.vdb csrc ucli.key spi_fcov_compile.log spi_fcov_sim.log novas.* verdiLog && rm -f ../wave/spi_uvm.fsdb
	@cd $(SIM_DIR) && vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -ntb_opts uvm \
		-cm $(FCOV_OPT) -cm_dir spi_func.vdb \
		-f filelist_spi_uvm.f -o simv_spi_fcov -l spi_fcov_compile.log
	@cd $(SIM_DIR) && ./simv_spi_fcov +UVM_NO_RELNOTES -cm $(FCOV_OPT) -cm_dir spi_func.vdb -l spi_fcov_sim.log

smoke: smoke-gpio smoke-spi

smoke-gpio:
	@cd $(SIM_DIR) && ./run_gpio.sh

smoke-spi:
	@cd $(SIM_DIR) && ./run.sh

summary:
	@echo ""
	@echo "========== FUNCTIONAL COVERAGE SUMMARY =========="
	@if [ -f $(SIM_DIR)/gpio_fcov_sim.log ]; then \
		grep -E "GPIO_SUMMARY|UVM_ERROR :|UVM_FATAL :" $(SIM_DIR)/gpio_fcov_sim.log; \
	elif [ -f $(SIM_DIR)/gpio_uvm_sim.log ]; then \
		grep -E "GPIO_SUMMARY|UVM_ERROR :|UVM_FATAL :" $(SIM_DIR)/gpio_uvm_sim.log; \
	else \
		echo "GPIO log not found"; \
	fi
	@if [ -f $(SIM_DIR)/spi_fcov_sim.log ]; then \
		grep -E "SPI_SUMMARY|UVM_ERROR :|UVM_FATAL :" $(SIM_DIR)/spi_fcov_sim.log; \
	elif [ -f $(SIM_DIR)/spi_uvm_sim.log ]; then \
		grep -E "SPI_SUMMARY|UVM_ERROR :|UVM_FATAL :" $(SIM_DIR)/spi_uvm_sim.log; \
	else \
		echo "SPI log not found"; \
	fi

clean:
	@cd $(SIM_DIR) && rm -rf \
		simv simv.daidir \
		simv_gpio simv_gpio.daidir \
		simv_gpio_uvm simv_gpio_uvm.daidir \
		simv_spi_uvm simv_spi_uvm.daidir \
		simv_gpio_fcov simv_gpio_fcov.daidir \
		simv_spi_fcov simv_spi_fcov.daidir \
		csrc ucli.key vc_hdrs.h \
		novas.* verdiLog
	@echo "clean done"

distclean: clean
	@rm -rf $(SIM_DIR)/*.log $(SIM_DIR)/*.vdb $(WAVE_DIR)/*.fsdb
	@echo "distclean done"

verdi-gpio:
	@test -f $(WAVE_DIR)/gpio_uvm.fsdb || (echo "Run 'make gpio' first" && false)
	@verdi -ssf $(WAVE_DIR)/gpio_uvm.fsdb &

verdi-spi:
	@test -f $(WAVE_DIR)/spi_uvm.fsdb || (echo "Run 'make spi' first" && false)
	@verdi -ssf $(WAVE_DIR)/spi_uvm.fsdb &

verdi-fcov-gpio:
	@test -d $(SIM_DIR)/gpio_func.vdb || (echo "Run 'make fcov-gpio' first" && false)
	@verdi -cov -covdir $(SIM_DIR)/gpio_func.vdb &

verdi-fcov-spi:
	@test -d $(SIM_DIR)/spi_func.vdb || (echo "Run 'make fcov-spi' first" && false)
	@verdi -cov -covdir $(SIM_DIR)/spi_func.vdb &
