#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p ../wave
rm -rf simv_spi_uvm simv_spi_uvm.daidir csrc ucli.key spi_uvm_compile.log spi_uvm_sim.log novas.* verdiLog
rm -f ../wave/spi_uvm.fsdb
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -ntb_opts uvm \
    -f filelist_spi_uvm.f -o simv_spi_uvm -l spi_uvm_compile.log
./simv_spi_uvm +UVM_NO_RELNOTES -l spi_uvm_sim.log
