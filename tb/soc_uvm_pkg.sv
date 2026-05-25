package soc_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum int {MODE_TIME_HM=0, MODE_TIME_SM=1, MODE_TIMER_STOP=2, MODE_TIMER_RUN=3} display_mode_e;

    class gpio_scoreboard extends uvm_component;
        `uvm_component_utils(gpio_scoreboard)

        int input_pass;
        int input_fail;
        int output_pass;
        int output_fail;
        bit button_seen[16];
        bit out_zone_seen[8];

        covergroup gpio_func_cg with function sample(int sample_kind, int sample_value);
            option.per_instance = 1;
            button_cp: coverpoint sample_value iff (sample_kind == 0) {
                bins btn_0000 = {0};
                bins btn_0001 = {1};
                bins btn_0010 = {2};
                bins btn_0011 = {3};
                bins btn_0100 = {4};
                bins btn_0101 = {5};
                bins btn_0110 = {6};
                bins btn_0111 = {7};
                bins btn_1000 = {8};
                bins btn_1001 = {9};
                bins btn_1010 = {10};
                bins btn_1011 = {11};
                bins btn_1100 = {12};
                bins btn_1101 = {13};
                bins btn_1110 = {14};
                bins btn_1111 = {15};
            }
            output_zone_cp: coverpoint sample_value iff (sample_kind == 1) {
                bins odr_00 = {0};
                bins odr_ff = {1};
                bins odr_55 = {2};
                bins odr_aa = {3};
                bins odr_0f = {4};
                bins odr_f0 = {5};
                bins odr_one_hot = {6};
                bins odr_random = {7};
            }
        endgroup

        function new(string name="gpio_scoreboard", uvm_component parent=null);
            super.new(name, parent);
            gpio_func_cg = new();
        endfunction

        function int out_zone(bit [7:0] data);
            if (data == 8'h00) return 0;
            if (data == 8'hff) return 1;
            if (data == 8'h55) return 2;
            if (data == 8'haa) return 3;
            if (data == 8'h0f) return 4;
            if (data == 8'hf0) return 5;
            if (data inside {8'h01,8'h02,8'h04,8'h08,8'h10,8'h20,8'h40,8'h80}) return 6;
            return 7;
        endfunction

        function void check_input(bit [3:0] exp_btn, bit [7:0] actual_idr);
            button_seen[exp_btn] = 1'b1;
            if (actual_idr[7:4] === exp_btn) begin
                input_pass++;
                gpio_func_cg.sample(0, exp_btn);
            end else begin
                input_fail++;
                `uvm_error("GPIO_SCB", $sformatf("input mismatch exp_btn=%h actual_idr=%02h", exp_btn, actual_idr))
            end
        endfunction

        function void check_output(bit [7:0] exp_odr, bit [7:0] actual_io);
            out_zone_seen[out_zone(exp_odr)] = 1'b1;
            if (actual_io === exp_odr) begin
                output_pass++;
                gpio_func_cg.sample(1, out_zone(exp_odr));
            end else begin
                output_fail++;
                `uvm_error("GPIO_SCB", $sformatf("output mismatch exp=%02h actual=%02h", exp_odr, actual_io))
            end
        endfunction

        function int button_cov_count();
            int n = 0;
            foreach (button_seen[i]) if (button_seen[i]) n++;
            return n;
        endfunction

        function int out_zone_cov_count();
            int n = 0;
            foreach (out_zone_seen[i]) if (out_zone_seen[i]) n++;
            return n;
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("GPIO_SUMMARY", $sformatf("input_pass=%0d input_fail=%0d button_cov=%0d/16", input_pass, input_fail, button_cov_count()), UVM_LOW)
            `uvm_info("GPIO_SUMMARY", $sformatf("output_pass=%0d output_fail=%0d output_zone_cov=%0d/8", output_pass, output_fail, out_zone_cov_count()), UVM_LOW)
            if (input_fail == 0 && output_fail == 0 && button_cov_count() == 16) begin
                `uvm_info("GPIO_SUMMARY", "[PASS] gpio_uvm_test", UVM_LOW)
            end else begin
                `uvm_error("GPIO_SUMMARY", "[FAIL] gpio_uvm_test")
            end
        endfunction
    endclass

    class gpio_env extends uvm_env;
        `uvm_component_utils(gpio_env)
        gpio_scoreboard scb;

        function new(string name="gpio_env", uvm_component parent=null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            scb = gpio_scoreboard::type_id::create("scb", this);
        endfunction
    endclass

    class gpio_uvm_test extends uvm_test;
        `uvm_component_utils(gpio_uvm_test)
        gpio_env env;
        virtual axi_lite_if axi_vif;
        virtual gpio_pin_if gpio_vif;

        function new(string name="gpio_uvm_test", uvm_component parent=null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = gpio_env::type_id::create("env", this);
            if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "axi_vif", axi_vif))
                `uvm_fatal("NOVIF", "axi_vif not found")
            if (!uvm_config_db#(virtual gpio_pin_if)::get(this, "", "gpio_vif", gpio_vif))
                `uvm_fatal("NOVIF", "gpio_vif not found")
        endfunction

        task run_phase(uvm_phase phase);
            bit [7:0] out_values[$];
            bit [31:0] rd;
            bit [7:0] data;

            phase.raise_objection(this);
            axi_vif.init_master();
            gpio_vif.ext_drive = 8'h00;
            gpio_vif.ext_drive_en = 8'h00;
            wait (axi_vif.ARESETN == 1'b1);
            repeat (5) @(posedge axi_vif.ACLK);

            out_values.push_back(8'h00);
            out_values.push_back(8'hff);
            out_values.push_back(8'h55);
            out_values.push_back(8'haa);
            out_values.push_back(8'h0f);
            out_values.push_back(8'hf0);
            out_values.push_back(8'h01); out_values.push_back(8'h02); out_values.push_back(8'h04); out_values.push_back(8'h08);
            out_values.push_back(8'h10); out_values.push_back(8'h20); out_values.push_back(8'h40); out_values.push_back(8'h80);

            axi_vif.write(32'h00, 32'h0000_00ff);
            foreach (out_values[i]) begin
                axi_vif.write(32'h08, out_values[i]);
                repeat (2) @(posedge axi_vif.ACLK);
                env.scb.check_output(out_values[i], gpio_vif.io_port);
            end
            repeat (32) begin
                data = $urandom_range(0, 255);
                axi_vif.write(32'h08, data);
                repeat (2) @(posedge axi_vif.ACLK);
                env.scb.check_output(data, gpio_vif.io_port);
            end

            axi_vif.write(32'h00, 32'h0000_0000);
            gpio_vif.ext_drive_en = 8'hff;
            for (int btn = 0; btn < 16; btn++) begin
                gpio_vif.ext_drive = {btn[3:0], 4'h0};
                repeat (2) @(posedge axi_vif.ACLK);
                axi_vif.read(32'h04, rd);
                env.scb.check_input(btn[3:0], rd[7:0]);
            end

            phase.drop_objection(this);
        endtask
    endclass

    class spi_scoreboard extends uvm_component;
        `uvm_component_utils(spi_scoreboard)

        int total_packets;
        int expected_accept;
        int expected_reject;
        int detected_reject;
        int false_accept;
        int false_reject;
        int spi_frame_fail;
        int slave_fail;
        int fnd_decode_fail;
        bit first_packet;
        bit [3:0] prev_seq;
        bit led_combo_seen[13];
        bit fnd_digit_seen[4][16];

        covergroup spi_func_cg with function sample(int sample_kind, int sample_a, int sample_b);
            option.per_instance = 1;
            led_combo_cp: coverpoint sample_a iff (sample_kind == 0) {
                bins led_51_time_hm_0 = {0};
                bins led_52_time_hm_1 = {1};
                bins led_54_time_hm_2 = {2};
                bins led_58_time_hm_3 = {3};
                bins led_61_time_sm_0 = {4};
                bins led_62_time_sm_1 = {5};
                bins led_64_time_sm_2 = {6};
                bins led_68_time_sm_3 = {7};
                bins led_80_timer_stop = {8};
                bins led_81_timer_run_0 = {9};
                bins led_82_timer_run_1 = {10};
                bins led_84_timer_run_2 = {11};
                bins led_88_timer_run_3 = {12};
            }
            seq_reject_cp: coverpoint sample_a iff (sample_kind == 1) {
                bins seq_dup_reject = {1};
            }
            fnd_pos_cp: coverpoint sample_a iff (sample_kind == 2) {
                bins an0 = {0};
                bins an1 = {1};
                bins an2 = {2};
                bins an3 = {3};
            }
            fnd_digit_cp: coverpoint sample_b iff (sample_kind == 2) {
                bins hex0 = {0};
                bins hex1 = {1};
                bins hex2 = {2};
                bins hex3 = {3};
                bins hex4 = {4};
                bins hex5 = {5};
                bins hex6 = {6};
                bins hex7 = {7};
                bins hex8 = {8};
                bins hex9 = {9};
                bins hexA = {10};
                bins hexB = {11};
                bins hexC = {12};
                bins hexD = {13};
                bins hexE = {14};
                bins hexF = {15};
            }
            fnd_decode_cross: cross fnd_pos_cp, fnd_digit_cp iff (sample_kind == 2) {
                bins an0_0 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex0);
                bins an0_1 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex1);
                bins an0_2 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex2);
                bins an0_3 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex3);
                bins an0_4 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex4);
                bins an0_5 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex5);
                bins an0_6 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex6);
                bins an0_7 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex7);
                bins an0_8 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex8);
                bins an0_9 = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hex9);
                bins an0_A = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hexA);
                bins an0_B = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hexB);
                bins an0_C = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hexC);
                bins an0_D = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hexD);
                bins an0_E = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hexE);
                bins an0_F = binsof(fnd_pos_cp.an0) && binsof(fnd_digit_cp.hexF);
                bins an1_0 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex0);
                bins an1_1 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex1);
                bins an1_2 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex2);
                bins an1_3 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex3);
                bins an1_4 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex4);
                bins an1_5 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex5);
                bins an1_6 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex6);
                bins an1_7 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex7);
                bins an1_8 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex8);
                bins an1_9 = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hex9);
                bins an1_A = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hexA);
                bins an1_B = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hexB);
                bins an1_C = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hexC);
                bins an1_D = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hexD);
                bins an1_E = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hexE);
                bins an1_F = binsof(fnd_pos_cp.an1) && binsof(fnd_digit_cp.hexF);
                bins an2_0 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex0);
                bins an2_1 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex1);
                bins an2_2 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex2);
                bins an2_3 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex3);
                bins an2_4 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex4);
                bins an2_5 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex5);
                bins an2_6 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex6);
                bins an2_7 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex7);
                bins an2_8 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex8);
                bins an2_9 = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hex9);
                bins an2_A = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hexA);
                bins an2_B = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hexB);
                bins an2_C = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hexC);
                bins an2_D = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hexD);
                bins an2_E = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hexE);
                bins an2_F = binsof(fnd_pos_cp.an2) && binsof(fnd_digit_cp.hexF);
                bins an3_0 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex0);
                bins an3_1 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex1);
                bins an3_2 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex2);
                bins an3_3 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex3);
                bins an3_4 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex4);
                bins an3_5 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex5);
                bins an3_6 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex6);
                bins an3_7 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex7);
                bins an3_8 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex8);
                bins an3_9 = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hex9);
                bins an3_A = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hexA);
                bins an3_B = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hexB);
                bins an3_C = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hexC);
                bins an3_D = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hexD);
                bins an3_E = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hexE);
                bins an3_F = binsof(fnd_pos_cp.an3) && binsof(fnd_digit_cp.hexF);
            }
        endgroup

        function new(string name="spi_scoreboard", uvm_component parent=null);
            super.new(name, parent);
            first_packet = 1'b1;
            spi_func_cg = new();
        endfunction

        function bit [7:0] fnd_decode(bit [3:0] digit);
            case (digit)
                4'h0: return 8'b1100_0000;
                4'h1: return 8'b1111_1001;
                4'h2: return 8'b1010_0100;
                4'h3: return 8'b1011_0000;
                4'h4: return 8'b1001_1001;
                4'h5: return 8'b1001_0010;
                4'h6: return 8'b1000_0010;
                4'h7: return 8'b1111_1000;
                4'h8: return 8'b1000_0000;
                4'h9: return 8'b1001_0000;
                4'hA: return 8'b1000_1000;
                4'hB: return 8'b1000_0011;
                4'hC: return 8'b1100_0110;
                4'hD: return 8'b1010_0001;
                4'hE: return 8'b1000_0110;
                default: return 8'b1000_1110;
            endcase
        endfunction

        function int led_combo_id(bit [7:0] led);
            bit [3:0] shift;
            shift = led[3:0];
            if (led[7:6] == 2'b01 && led[5:4] == 2'b01) begin
                case (shift) 4'b0001:return 0; 4'b0010:return 1; 4'b0100:return 2; 4'b1000:return 3; endcase
            end
            if (led[7:6] == 2'b01 && led[5:4] == 2'b10) begin
                case (shift) 4'b0001:return 4; 4'b0010:return 5; 4'b0100:return 6; 4'b1000:return 7; endcase
            end
            if (led[7:6] == 2'b10 && led[5:4] == 2'b00 && shift == 4'b0000) return 8;
            if (led[7:6] == 2'b10 && led[5:4] == 2'b00) begin
                case (shift) 4'b0001:return 9; 4'b0010:return 10; 4'b0100:return 11; 4'b1000:return 12; endcase
            end
            return -1;
        endfunction

        function bit expected_packet_accept(bit [31:0] packet);
            bit [3:0] seq = packet[27:24];
            if (first_packet) return 1'b1;
            return (seq != prev_seq);
        endfunction

        function void update_seq(bit [31:0] packet, bit accepted, bit actual_updated);
            total_packets++;
            if (accepted) expected_accept++; else expected_reject++;
            if (!accepted && !actual_updated) begin
                detected_reject++;
                spi_func_cg.sample(1, 1, 0);
            end
            if (!accepted && actual_updated) false_accept++;
            if (accepted && !actual_updated) false_reject++;
            if (accepted && actual_updated) begin
                prev_seq = packet[27:24];
                first_packet = 1'b0;
            end
        endfunction

        function void check_spi_frame(bit [31:0] exp, bit [31:0] actual);
            if (actual !== exp) begin
                spi_frame_fail++;
                `uvm_error("SPI_SCB", $sformatf("frame mismatch exp=%08h actual=%08h", exp, actual))
            end
        endfunction

        function void check_slave(bit [31:0] packet, bit [7:0] actual_led, bit [15:0] actual_fnd);
            int id;
            bit [7:0] exp_led = packet[23:16];
            bit [15:0] exp_fnd = packet[15:0];
            if (actual_led !== exp_led || actual_fnd !== exp_fnd) begin
                slave_fail++;
                `uvm_error("SPI_SCB", $sformatf("slave mismatch exp_led=%02h act_led=%02h exp_fnd=%04h act_fnd=%04h", exp_led, actual_led, exp_fnd, actual_fnd))
            end
            id = led_combo_id(exp_led);
            if (id >= 0) begin
                led_combo_seen[id] = 1'b1;
                spi_func_cg.sample(0, id, 0);
            end else `uvm_error("SPI_SCB", $sformatf("illegal led combo %02h", exp_led))
        endfunction

        function int led_cov_count();
            int n = 0;
            foreach (led_combo_seen[i]) if (led_combo_seen[i]) n++;
            return n;
        endfunction

        function int fnd_cov_count();
            int n = 0;
            foreach (fnd_digit_seen[p,d]) if (fnd_digit_seen[p][d]) n++;
            return n;
        endfunction

        function void sample_fnd_decode(int pos, bit [3:0] digit, bit [7:0] actual_out);
            bit [7:0] exp = fnd_decode(digit);
            if (actual_out !== exp) begin
                fnd_decode_fail++;
                `uvm_error("FND_SCB", $sformatf("decode mismatch pos=%0d digit=%h exp=%02h actual=%02h", pos, digit, exp, actual_out))
            end else begin
                fnd_digit_seen[pos][digit] = 1'b1;
                spi_func_cg.sample(2, pos, digit);
            end
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("SPI_SUMMARY", $sformatf("total=%0d accept=%0d reject=%0d detected_reject=%0d false_accept=%0d false_reject=%0d", total_packets, expected_accept, expected_reject, detected_reject, false_accept, false_reject), UVM_LOW)
            `uvm_info("SPI_SUMMARY", $sformatf("spi_frame_fail=%0d slave_fail=%0d fnd_decode_fail=%0d", spi_frame_fail, slave_fail, fnd_decode_fail), UVM_LOW)
            `uvm_info("SPI_SUMMARY", $sformatf("led_combo_cov=%0d/13 fnd_decode_cov=%0d/64", led_cov_count(), fnd_cov_count()), UVM_LOW)
            if (spi_frame_fail == 0 && slave_fail == 0 && fnd_decode_fail == 0 && false_accept == 0 && false_reject == 0) begin
                `uvm_info("SPI_SUMMARY", "[PASS] spi_mirror_uvm_test", UVM_LOW)
            end else begin
                `uvm_error("SPI_SUMMARY", "[FAIL] spi_mirror_uvm_test")
            end
        endfunction
    endclass

    class spi_env extends uvm_env;
        `uvm_component_utils(spi_env)
        spi_scoreboard scb;
        function new(string name="spi_env", uvm_component parent=null);
            super.new(name, parent);
        endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            scb = spi_scoreboard::type_id::create("scb", this);
        endfunction
    endclass

    class spi_mirror_uvm_test extends uvm_test;
        `uvm_component_utils(spi_mirror_uvm_test)
        spi_env env;
        virtual axi_lite_if axi_vif;
        virtual spi_line_if spi_vif;
        virtual spi_result_if res_vif;

        function new(string name="spi_mirror_uvm_test", uvm_component parent=null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = spi_env::type_id::create("env", this);
            if (!uvm_config_db#(virtual axi_lite_if)::get(this, "", "axi_vif", axi_vif))
                `uvm_fatal("NOVIF", "axi_vif not found")
            if (!uvm_config_db#(virtual spi_line_if)::get(this, "", "spi_vif", spi_vif))
                `uvm_fatal("NOVIF", "spi_vif not found")
            if (!uvm_config_db#(virtual spi_result_if)::get(this, "", "res_vif", res_vif))
                `uvm_fatal("NOVIF", "res_vif not found")
        endfunction

        function bit [3:0] onehot_shift(int sel);
            case (sel % 4)
                0: return 4'b0001;
                1: return 4'b0010;
                2: return 4'b0100;
                default: return 4'b1000;
            endcase
        endfunction

        function bit [7:0] make_led_combo(int id);
            case (id)
                0,1,2,3:   return {2'b01, 2'b01, onehot_shift(id)};
                4,5,6,7:   return {2'b01, 2'b10, onehot_shift(id-4)};
                8:         return {2'b10, 2'b00, 4'b0000};
                9,10,11,12:return {2'b10, 2'b00, onehot_shift(id-9)};
                default:   return 8'h00;
            endcase
        endfunction

        function bit [31:0] make_packet();
            bit [3:0] seq;
            bit [7:0] led;
            bit [15:0] fnd;
            seq = $urandom_range(0, 15);
            led = make_led_combo($urandom_range(0, 12));
            fnd = $urandom_range(0, 16'hffff);
            return {4'h0, seq, led, fnd};
        endfunction

        task automatic start_transfer(bit [31:0] packet);
            axi_vif.write(32'h0C, 32'd4);
            axi_vif.write(32'h08, packet);
            axi_vif.write(32'h00, 32'h1);
            axi_vif.write(32'h00, 32'h0);
        endtask

        task automatic capture_spi_frame(output bit [31:0] frame);
            frame = 32'd0;
            wait (spi_vif.ss == 1'b0);
            for (int i = 0; i < 32; i++) begin
                @(posedge spi_vif.sclk);
                frame = {frame[30:0], spi_vif.mosi};
            end
            wait (spi_vif.ss == 1'b1);
        endtask

        task automatic check_fnd_window(bit [15:0] fnd_data);
            bit [3:0] digits[4];
            bit [3:0] sels[4];
            digits[0] = fnd_data[3:0];
            digits[1] = fnd_data[7:4];
            digits[2] = fnd_data[11:8];
            digits[3] = fnd_data[15:12];
            sels[0] = 4'b1110;
            sels[1] = 4'b1101;
            sels[2] = 4'b1011;
            sels[3] = 4'b0111;
            for (int pos = 0; pos < 4; pos++) begin
                wait (res_vif.fnd_sel == sels[pos]);
                repeat (2) @(posedge axi_vif.ACLK);
                env.scb.sample_fnd_decode(pos, digits[pos], res_vif.fnd_out);
            end
        endtask

        task automatic send_and_check(bit [31:0] packet);
            bit [31:0] actual_frame;
            bit exp_accept;
            bit before_toggle;
            bit after_toggle;
            bit actual_updated;
            bit [7:0] prev_led;
            bit [15:0] prev_fnd;

            exp_accept = env.scb.expected_packet_accept(packet);
            before_toggle = res_vif.packet_update_en;
            prev_led = res_vif.led_data;
            prev_fnd = res_vif.fnd_data;

            fork
                capture_spi_frame(actual_frame);
                start_transfer(packet);
            join

            env.scb.check_spi_frame(packet, actual_frame);

            if (exp_accept) begin
                repeat (200) begin
                    @(posedge axi_vif.ACLK);
                    if (res_vif.packet_update_en != before_toggle) break;
                end
                after_toggle = res_vif.packet_update_en;
                actual_updated = (after_toggle != before_toggle);
                env.scb.update_seq(packet, exp_accept, actual_updated);
                if (actual_updated) begin
                    env.scb.check_slave(packet, res_vif.led_data, res_vif.fnd_data);
                    check_fnd_window(packet[15:0]);
                end
            end else begin
                repeat (100) @(posedge axi_vif.ACLK);
                after_toggle = res_vif.packet_update_en;
                actual_updated = (after_toggle != before_toggle);
                env.scb.update_seq(packet, exp_accept, actual_updated);
                if (actual_updated || res_vif.led_data !== prev_led || res_vif.fnd_data !== prev_fnd) begin
                    env.scb.slave_fail++;
                    `uvm_error("SPI_SCB", $sformatf("duplicate seq updated output packet=%08h", packet))
                end
            end
        endtask

        task run_phase(uvm_phase phase);
            bit [31:0] packet;
            phase.raise_objection(this);
            axi_vif.init_master();
            wait (axi_vif.ARESETN == 1'b1);
            repeat (10) @(posedge axi_vif.ACLK);

            repeat (64) begin
                packet = make_packet();
                send_and_check(packet);
            end

            phase.drop_objection(this);
        endtask
    endclass
endpackage
