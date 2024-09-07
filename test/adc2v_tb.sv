`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module adc2v_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam PIPE_WIDTH = 4;
    localparam FRACTION = 20;

    logic clk;
    logic rst;

    logic adc_ready_in;
    logic adc_valid_in;
    logic [ADC_WIDTH-1:0] adc_data_in;

    logic voltage_ready_out;
    logic voltage_valid_out;
    logic [DATA_WIDTH-1:0] voltage_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    adc2v #(
        .DATA_WIDTH     (DATA_WIDTH),
        .FRACTION       (FRACTION),
        .PIPE_WIDTH     (PIPE_WIDTH)
    ) adc2v (
        .clk    (clk),
        .rst    (rst),

        .adc_ready_in   (adc_ready_in),
        .adc_valid_in   (adc_valid_in),
        .adc_data_in    (adc_data_in ),

        .voltage_ready_out  (voltage_ready_out),
        .voltage_valid_out  (voltage_valid_out),
        .voltage_data_out   (voltage_data_out )
    );

    int fd;
    string line;
    bit valid;
    logic [DATA_WIDTH-1:0] hex;

    initial begin
        fd = $fopen("../samples/newDataLerp.hex", "r");
        voltage_ready_out = 1'b0;
        adc_valid_in = 1'b0;
        adc_data_in = {DATA_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        while (!$feof(fd)) begin
            #(CLK_PERIOD);

            //voltage_ready_out <= $urandom_range(1'b0, 1'b1);
            voltage_ready_out <= 1'b1;
            if (adc_ready_in | ~adc_valid_in) begin
                //valid = $urandom_range(1'b0, 1'b1);
                valid = 1'b1;
                $fgets(line, fd);
                hex = line.atohex();
                adc_data_in <= hex;
                adc_valid_in <= valid;
            end
        end
        $fclose(fd);
        $stop;
    end

endmodule