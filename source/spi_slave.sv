`timescale 1ns / 1ps


module spi_slave_top (
    input  logic       clk,
    input  logic       rst,
    input  logic       ja_sclk,
    input  logic       ja_mosi,
    input  logic       ja_ss,
    output logic       ja_miso,
    output logic [7:0] led,
    output logic [6:0] seg,
    output logic       dp,
    output logic [3:0] an
);
    logic       miso;
    logic       packet_update_en;
    logic [7:0] led_data;
    logic [15:0] fnd_data;
    logic [7:0] fnd_out;

    assign ja_miso = miso;
    assign seg   = fnd_out[6:0];
    assign dp    = fnd_out[7];

    spi_slave U_SPI_SLAVE (
        .clk              (clk),
        .rst              (rst),
        .sclk             (ja_sclk),
        .mosi             (ja_mosi),
        .ss               (ja_ss),
        .miso             (miso),
        .packet_update_en (packet_update_en),
        .led_data         (led_data),
        .fnd_data         (fnd_data)
    );

    window_controller U_WINDOW_CONTROLLER (
        .clk              (clk),
        .rst              (rst),
        .packet_update_en (packet_update_en),
        .led_data         (led_data),
        .fnd_data         (fnd_data),
        .led_out          (led),
        .fnd_out          (fnd_out),
        .fnd_sel          (an)
    );
endmodule


module spi_slave (
    input  logic       clk,
    input  logic       rst,
    input  logic       sclk,
    input  logic       mosi,
    input  logic       ss,
    output logic       miso,
    output logic       packet_update_en,
    output logic [7:0] led_data,
    output logic [15:0] fnd_data
);
    // 32bit packet, MSB first
    // [31:28] reserved, [27:24] seq / heartbeat,
    // [23:16] led[7:0], [15:0] fnd_data
    logic [31:0] rx_shift;
    logic [ 5:0] rx_count;
    logic        sclk_d1;
    logic        sclk_d2;
    logic        sclk_prev;
    logic        ss_d1;
    logic        ss_d2;
    logic        ss_prev;
    logic        mosi_d1;
    logic        mosi_d2;
    logic        sclk_rise;
    logic        ss_rise;
    logic [ 3:0] rx_seq;
    logic [ 7:0] rx_led_data;
    logic [15:0] rx_fnd_data;

    logic [ 3:0] prev_seq;
    logic        first_packet;
    logic        packet_update_ok;

    assign miso = 1'b0;
    assign rx_seq      = rx_shift[27:24];
    assign rx_led_data = rx_shift[23:16];
    assign rx_fnd_data = rx_shift[15:0];
    assign sclk_rise = sclk_d2 && !sclk_prev;
    assign ss_rise   = ss_d2 && !ss_prev;
    assign packet_update_ok = (rx_count == 6'd32) && (first_packet || (rx_seq != prev_seq));

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sclk_d1   <= 1'b0;
            sclk_d2   <= 1'b0;
            sclk_prev <= 1'b0;
            ss_d1     <= 1'b1;
            ss_d2     <= 1'b1;
            ss_prev   <= 1'b1;
            mosi_d1   <= 1'b0;
            mosi_d2   <= 1'b0;
        end else begin
            sclk_d1   <= sclk;
            sclk_d2   <= sclk_d1;
            sclk_prev <= sclk_d2;
            ss_d1     <= ss;
            ss_d2     <= ss_d1;
            ss_prev   <= ss_d2;
            mosi_d1   <= mosi;
            mosi_d2   <= mosi_d1;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_shift         <= 32'd0;
            rx_count         <= 6'd0;
            prev_seq         <= 4'd0;
            first_packet     <= 1'b1;
            packet_update_en <= 1'b0;
            led_data         <= 8'd0;
            fnd_data         <= 16'd0;
        end else begin
            if (ss_d2) begin
                rx_shift <= 32'd0;
                rx_count <= 6'd0;
            end else if (sclk_rise) begin
                rx_shift <= {rx_shift[30:0], mosi_d2};
                if (rx_count < 6'd32) begin
                    rx_count <= rx_count + 6'd1;
                end
            end

            if (ss_rise && packet_update_ok) begin
                prev_seq         <= rx_seq;
                first_packet     <= 1'b0;
                packet_update_en <= ~packet_update_en;
                led_data         <= rx_led_data;
                fnd_data         <= rx_fnd_data;
            end
        end
    end
endmodule


module window_controller #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int TIMEOUT_MS  = 300
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        packet_update_en,
    input  logic [ 7:0] led_data,
    input  logic [15:0] fnd_data,
    output logic [ 7:0] led_out,
    output logic [ 7:0] fnd_out,
    output logic [ 3:0] fnd_sel
);
    localparam int TIMEOUT_COUNT = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;
    localparam int TIMEOUT_WIDTH = $clog2(TIMEOUT_COUNT + 1);

    logic [15:0] scan_cnt;
    logic [TIMEOUT_WIDTH-1:0] timeout_cnt;
    logic packet_update_prev;
    logic update_event;
    logic timeout_error;
    logic [ 3:0] fnd_digit;

    assign update_event  = packet_update_en ^ packet_update_prev;
    assign timeout_error = (timeout_cnt == TIMEOUT_COUNT[TIMEOUT_WIDTH-1:0]);
    assign led_out = timeout_error ? 8'hff : led_data;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_cnt           <= 16'd0;
            timeout_cnt        <= '0;
            packet_update_prev <= 1'b0;
        end else begin
            scan_cnt <= scan_cnt + 16'd1;
            packet_update_prev <= packet_update_en;

            if (update_event) begin
                timeout_cnt <= '0;
            end else if (!timeout_error) begin
                timeout_cnt <= timeout_cnt + {{(TIMEOUT_WIDTH - 1) {1'b0}}, 1'b1};
            end
        end
    end

    always_comb begin
        case (scan_cnt[15:14])
            2'd0: begin
                fnd_sel   = 4'b1110;
                fnd_digit = fnd_data[3:0];
            end
            2'd1: begin
                fnd_sel   = 4'b1101;
                fnd_digit = fnd_data[7:4];
            end
            2'd2: begin
                fnd_sel   = 4'b1011;
                fnd_digit = fnd_data[11:8];
            end
            default: begin
                fnd_sel   = 4'b0111;
                fnd_digit = fnd_data[15:12];
            end
        endcase

        case (fnd_digit)
            4'h0: fnd_out = 8'b1100_0000;
            4'h1: fnd_out = 8'b1111_1001;
            4'h2: fnd_out = 8'b1010_0100;
            4'h3: fnd_out = 8'b1011_0000;
            4'h4: fnd_out = 8'b1001_1001;
            4'h5: fnd_out = 8'b1001_0010;
            4'h6: fnd_out = 8'b1000_0010;
            4'h7: fnd_out = 8'b1111_1000;
            4'h8: fnd_out = 8'b1000_0000;
            4'h9: fnd_out = 8'b1001_0000;
            4'hA: fnd_out = 8'b1000_1000;
            4'hB: fnd_out = 8'b1000_0011;
            4'hC: fnd_out = 8'b1100_0110;
            4'hD: fnd_out = 8'b1010_0001;
            4'hE: fnd_out = 8'b1000_0110;
            default: fnd_out = 8'b1000_1110;
        endcase

    end
endmodule
