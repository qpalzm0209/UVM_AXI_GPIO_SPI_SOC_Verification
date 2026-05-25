`timescale 1ns/1ps

module tb_gpio_smoke;
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

    tri [7:0] io_port;
    logic [7:0] ext_drive;
    logic [7:0] ext_drive_en;

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : g_ext_drive
            assign io_port[i] = ext_drive_en[i] ? ext_drive[i] : 1'bz;
        end
    endgenerate

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    GPIO8_v1_0 #(
        .C_S00_AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .C_S00_AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) u_gpio (
        .io_port(io_port),
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

    initial begin
        $fsdbDumpfile("../wave/gpio_smoke.fsdb");
        $fsdbDumpvars(0, tb_gpio_smoke);
    end

    initial begin
        logic [31:0] rd;

        axi_init();
        ext_drive = 8'h00;
        ext_drive_en = 8'h00;

        rstn = 1'b0;
        repeat (10) @(posedge clk);
        rstn = 1'b1;
        repeat (10) @(posedge clk);

        axi_write(32'h00, 32'h0000_00FF); // all pins output
        axi_write(32'h08, 32'h0000_0090); // ODR = 8'h90
        repeat (2) @(posedge clk);
        if (io_port !== 8'h90) begin
            $fatal(1, "GPIO output mismatch exp=90 act=%02h", io_port);
        end
        axi_read(32'h04, rd);
        if (rd[7:0] !== 8'h90) begin
            $fatal(1, "GPIO IDR readback mismatch exp=90 act=%02h", rd[7:0]);
        end
        $display("[CHECK] GPIO output mode ODR=90 io_port=%02h IDR=%02h", io_port, rd[7:0]);

        axi_write(32'h00, 32'h0000_0000); // all pins input
        ext_drive = 8'hA5;
        ext_drive_en = 8'hFF;
        repeat (2) @(posedge clk);
        axi_read(32'h04, rd);
        if (rd[7:0] !== 8'hA5) begin
            $fatal(1, "GPIO input read mismatch exp=A5 act=%02h", rd[7:0]);
        end
        $display("[CHECK] GPIO input mode external=A5 IDR=%02h", rd[7:0]);

        $display("[PASS] AXI GPIO smoke test passed");
        #100;
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
endmodule