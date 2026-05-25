`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;
import soc_uvm_pkg::*;

module tb_spi_uvm_top;
    logic clk;
    axi_lite_if axi_if(clk);
    spi_line_if spi_if();
    spi_result_if res_if();

    logic spi_miso;
    logic slave_miso;
    logic [7:0] slave_led;
    logic [6:0] slave_seg;
    logic slave_dp;
    logic [3:0] slave_an;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    spi_master_v1_0 u_master (
        .spi_sclk(spi_if.sclk),
        .spi_mosi(spi_if.mosi),
        .spi_ss(spi_if.ss),
        .spi_miso(spi_miso),
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

    spi_slave_top u_slave (
        .clk(clk),
        .rst(~axi_if.ARESETN),
        .ja_sclk(spi_if.sclk),
        .ja_mosi(spi_if.mosi),
        .ja_ss(spi_if.ss),
        .ja_miso(slave_miso),
        .led(slave_led),
        .seg(slave_seg),
        .dp(slave_dp),
        .an(slave_an)
    );

    assign spi_miso = 1'b0;
    assign res_if.packet_update_en = u_slave.packet_update_en;
    assign res_if.led_data = u_slave.led_data;
    assign res_if.fnd_data = u_slave.fnd_data;
    assign res_if.fnd_out = u_slave.fnd_out;
    assign res_if.fnd_sel = slave_an;

    initial begin
        $fsdbDumpfile("../wave/spi_uvm.fsdb");
        $fsdbDumpvars(0, tb_spi_uvm_top);
    end

    initial begin
        axi_if.ARESETN = 1'b0;
        axi_if.init_master();
        repeat (10) @(posedge clk);
        axi_if.ARESETN = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual axi_lite_if)::set(null, "*", "axi_vif", axi_if);
        uvm_config_db#(virtual spi_line_if)::set(null, "*", "spi_vif", spi_if);
        uvm_config_db#(virtual spi_result_if)::set(null, "*", "res_vif", res_if);
        run_test("spi_mirror_uvm_test");
    end
endmodule
