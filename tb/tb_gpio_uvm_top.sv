`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import soc_uvm_pkg::*;

module tb_gpio_uvm_top;
    logic clk;
    axi_lite_if axi_if(clk);
    gpio_pin_if gpio_if();

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    GPIO8_v1_0 u_gpio (
        .io_port(gpio_if.io_port),
        .s00_axi_aclk(clk),
        .s00_axi_aresetn(axi_if.ARESETN),
        .s00_axi_awaddr(axi_if.AWADDR),
        .s00_axi_awprot(axi_if.AWPROT),
        .s00_axi_awvalid(axi_if.AWVALID),
        .s00_axi_awready(axi_if.AWREADY),
        .s00_axi_wdata(axi_if.WDATA),
        .s00_axi_wstrb(axi_if.WSTRB),
        .s00_axi_wvalid(axi_if.WVALID),
        .s00_axi_wready(axi_if.WREADY),
        .s00_axi_bresp(axi_if.BRESP),
        .s00_axi_bvalid(axi_if.BVALID),
        .s00_axi_bready(axi_if.BREADY),
        .s00_axi_araddr(axi_if.ARADDR),
        .s00_axi_arprot(axi_if.ARPROT),
        .s00_axi_arvalid(axi_if.ARVALID),
        .s00_axi_arready(axi_if.ARREADY),
        .s00_axi_rdata(axi_if.RDATA),
        .s00_axi_rresp(axi_if.RRESP),
        .s00_axi_rvalid(axi_if.RVALID),
        .s00_axi_rready(axi_if.RREADY)
    );

    initial begin
        $fsdbDumpfile("../wave/gpio_uvm.fsdb");
        $fsdbDumpvars(0, tb_gpio_uvm_top);
    end

    initial begin
        axi_if.ARESETN = 1'b0;
        axi_if.init_master();
        gpio_if.ext_drive = 8'h00;
        gpio_if.ext_drive_en = 8'h00;
        repeat (10) @(posedge clk);
        axi_if.ARESETN = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual axi_lite_if)::set(null, "*", "axi_vif", axi_if);
        uvm_config_db#(virtual gpio_pin_if)::set(null, "*", "gpio_vif", gpio_if);
        run_test("gpio_uvm_test");
    end
endmodule
