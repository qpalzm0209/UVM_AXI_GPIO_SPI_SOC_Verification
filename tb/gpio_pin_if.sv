interface gpio_pin_if;
    logic [7:0] ext_drive;
    logic [7:0] ext_drive_en;
    tri   [7:0] io_port;

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : g_drive
            assign io_port[i] = ext_drive_en[i] ? ext_drive[i] : 1'bz;
        end
    endgenerate
endinterface
