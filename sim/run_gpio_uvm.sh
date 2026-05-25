#!/bin/bash
set -e
cd "$(dirname "$0")"
mkdir -p ../wave
rm -rf simv_gpio_uvm simv_gpio_uvm.daidir csrc ucli.key gpio_uvm_compile.log gpio_uvm_sim.log novas.* verdiLog
rm -f ../wave/gpio_uvm.fsdb
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -ntb_opts uvm \
    -f filelist_gpio_uvm.f -o simv_gpio_uvm -l gpio_uvm_compile.log
./simv_gpio_uvm +UVM_NO_RELNOTES -l gpio_uvm_sim.log
