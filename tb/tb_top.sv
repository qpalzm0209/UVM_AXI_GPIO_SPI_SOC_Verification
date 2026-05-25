`timescale 1ns/1ps

module tb_top;
    localparam int AXI_ADDR_WIDTH = 4;
    localparam int AXI_DATA_WIDTH = 32;

    logic clk;
    logic rstn;

    logic [AXI_ADDR_WIDTH-1:0] awaddr;
    logic [2:0] awprot;
    logic awvalid;
    logic awready;
    logic [AXI_DATA_WIDTH-1:0] wdata;
    logic [(AXI_DATA_WIDTH/8)-1:0] wstrb;
    logic wvalid;
    logic wready;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;
    logic [AXI_ADDR_WIDTH-1:0] araddr;
    logic [2:0] arprot;
    logic arvalid;
    logic arready;
    logic [AXI_DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    logic spi_sclk;
    logic spi_mosi;
    logic spi_ss;
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

    spi_master_v1_0 #(
        .C_S00_AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) u_master (
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_ss(spi_ss),
        .spi_miso(spi_miso),
        .s00_axi_aclk(clk),
        .s00_axi_aresetn(rstn),
        .s00_axi_awaddr(awaddr),
        .s00_axi_awprot(awprot),
        .s00_axi_awvalid(awvalid),
        .s00_axi_awready(awready),
        .s00_axi_wdata(wdata),
        .s00_axi_wstrb(wstrb),
        .s00_axi_wvalid(wvalid),
        .s00_axi_wready(wready),
        .s00_axi_bresp(bresp),
        .s00_axi_bvalid(bvalid),
        .s00_axi_bready(bready),
        .s00_axi_araddr(araddr),
        .s00_axi_arprot(arprot),
        .s00_axi_arvalid(arvalid),
        .s00_axi_arready(arready),
        .s00_axi_rdata(rdata),
        .s00_axi_rresp(rresp),
        .s00_axi_rvalid(rvalid),
        .s00_axi_rready(rready)
    );

    spi_slave_top u_slave (
        .clk(clk),
        .rst(~rstn),
        .ja_sclk(spi_sclk),
        .ja_mosi(spi_mosi),
        .ja_ss(spi_ss),
        .ja_miso(slave_miso),
        .led(slave_led),
        .seg(slave_seg),
        .dp(slave_dp),
        .an(slave_an)
    );

    assign spi_miso = 1'b0;

    initial begin
        $fsdbDumpfile("../wave/dump.fsdb");
        $fsdbDumpvars(0, tb_top);
    end

    initial begin
        axi_init();
        rstn = 1'b0;
        repeat (10) @(posedge clk);
        rstn = 1'b1;
        repeat (10) @(posedge clk);

        send_and_check(32'h0190_1234, 8'h90, 16'h1234);
        send_and_check(32'h02A5_5678, 8'hA5, 16'h5678);

        $display("[PASS] AXI -> SPI master -> SPI slave end-to-end test passed");
        #1000;
        $finish;
    end

    task automatic axi_init();
        awaddr  = '0;
        awprot  = '0;
        awvalid = 1'b0;
        wdata   = '0;
        wstrb   = '1;
        wvalid  = 1'b0;
        bready  = 1'b0;
        araddr  = '0;
        arprot  = '0;
        arvalid = 1'b0;
        rready  = 1'b0;
    endtask

    task automatic axi_write(input [31:0] addr, input [31:0] data);
        @(posedge clk);
        awaddr  <= addr[AXI_ADDR_WIDTH-1:0];
        awvalid <= 1'b1;
        wdata   <= data;
        wstrb   <= 4'hF;
        wvalid  <= 1'b1;
        bready  <= 1'b1;

        wait (awready && wready);
        @(posedge clk);
        awvalid <= 1'b0;
        wvalid  <= 1'b0;

        wait (bvalid && bready);
        @(posedge clk);
        bready <= 1'b0;
    endtask

    task automatic axi_read(input [31:0] addr, output [31:0] data);
        @(posedge clk);
        araddr  <= addr[AXI_ADDR_WIDTH-1:0];
        arvalid <= 1'b1;
        rready  <= 1'b1;

        wait (arready);
        @(posedge clk);
        arvalid <= 1'b0;

        wait (rvalid && rready);
        data = rdata;
        @(posedge clk);
        rready <= 1'b0;
    endtask

    task automatic start_transfer(input [31:0] packet);
        axi_write(32'h0C, 32'd4);
        axi_write(32'h08, packet);
        axi_write(32'h00, 32'h1);
        axi_write(32'h00, 32'h0);
    endtask

    task automatic capture_spi_frame(output [31:0] frame);
        int i;
        frame = 32'd0;
        wait (spi_ss == 1'b0);
        for (i = 0; i < 32; i++) begin
            @(posedge spi_sclk);
            frame = {frame[30:0], spi_mosi};
        end
        wait (spi_ss == 1'b1);
    endtask

    task automatic wait_slave_update(input [7:0] exp_led, input [15:0] exp_fnd);
        wait (u_slave.led_data == exp_led && u_slave.fnd_data == exp_fnd);
        repeat (5) @(posedge clk);
    endtask

    task automatic send_and_check(input [31:0] packet, input [7:0] exp_led, input [15:0] exp_fnd);
        logic [31:0] actual_frame;

        fork
            begin
                capture_spi_frame(actual_frame);
            end
            begin
                start_transfer(packet);
            end
        join

        if (actual_frame !== packet) begin
            $fatal(1, "SPI frame mismatch exp=%08h act=%08h", packet, actual_frame);
        end

        wait_slave_update(exp_led, exp_fnd);
        $display("[CHECK] packet=%08h led=%02h fnd=%04h", packet, exp_led, exp_fnd);
    endtask
endmodule