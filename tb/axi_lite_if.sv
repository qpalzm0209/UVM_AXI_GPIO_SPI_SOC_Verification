interface axi_lite_if #(parameter int ADDR_WIDTH = 4, DATA_WIDTH = 32) (input logic ACLK);
    logic ARESETN;
    logic [ADDR_WIDTH-1:0] AWADDR;
    logic [2:0] AWPROT;
    logic AWVALID;
    logic AWREADY;
    logic [DATA_WIDTH-1:0] WDATA;
    logic [(DATA_WIDTH/8)-1:0] WSTRB;
    logic WVALID;
    logic WREADY;
    logic [1:0] BRESP;
    logic BVALID;
    logic BREADY;
    logic [ADDR_WIDTH-1:0] ARADDR;
    logic [2:0] ARPROT;
    logic ARVALID;
    logic ARREADY;
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0] RRESP;
    logic RVALID;
    logic RREADY;

    task automatic init_master();
        AWADDR  <= '0;
        AWPROT  <= '0;
        AWVALID <= 1'b0;
        WDATA   <= '0;
        WSTRB   <= '1;
        WVALID  <= 1'b0;
        BREADY  <= 1'b0;
        ARADDR  <= '0;
        ARPROT  <= '0;
        ARVALID <= 1'b0;
        RREADY  <= 1'b0;
    endtask

    task automatic write(input [31:0] addr, input [31:0] data);
        @(posedge ACLK);
        AWADDR  <= addr[ADDR_WIDTH-1:0];
        AWVALID <= 1'b1;
        WDATA   <= data;
        WSTRB   <= '1;
        WVALID  <= 1'b1;
        BREADY  <= 1'b1;
        wait (AWREADY && WREADY);
        @(posedge ACLK);
        AWVALID <= 1'b0;
        WVALID  <= 1'b0;
        wait (BVALID && BREADY);
        @(posedge ACLK);
        BREADY <= 1'b0;
    endtask

    task automatic read(input [31:0] addr, output [31:0] data);
        @(posedge ACLK);
        ARADDR  <= addr[ADDR_WIDTH-1:0];
        ARVALID <= 1'b1;
        RREADY  <= 1'b1;
        wait (ARREADY);
        @(posedge ACLK);
        ARVALID <= 1'b0;
        wait (RVALID && RREADY);
        data = RDATA;
        @(posedge ACLK);
        RREADY <= 1'b0;
    endtask
endinterface
