`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module m10_cnn1d_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam FRACTION = 16; // position of the decimal point from the right 
    localparam PIPE_WIDTH = 4;
  
    localparam SUBSAMPLE_FACTOR = 400;
    localparam ADC_REF = 2500;
    localparam BIAS = 0;
    localparam SCALE_FACTOR = 32'h00000400;
    
    localparam CONV_BIASES_INIT_FILE = "../weights/conv1d_biases_16I16F.hex";
    localparam CONV_WEIGHTS_INIT_FILE = "../weights/conv1d_weights_16I16F.hex";
    localparam NUM_FILTERS = 2;
    localparam FILTER_SIZE = 5;
    
    localparam POOL_SIZE = 256;
    localparam NEURON_BIASES_INIT_FILE = "../weights/fc_biases_16I16F.hex";
    localparam NEURON_WEIGHTS_INIT_FILE = "../weights/fc_weights_16I16F.hex";
    localparam NUM_NEURONS = 2;

    logic clk;
    logic rst;

    logic cnn_ready_in;
    logic cnn_valid_in;
    logic [ADC_WIDTH-1:0] cnn_data_in;

    logic cnn_ready_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    m08_cnn1d #(
        .DATA_WIDTH (DATA_WIDTH),
        .CONV_WEIGHTS_INIT_FILE (CONV_WEIGHTS_INIT_FILE),
        .CONV_BIASES_INIT_FILE (CONV_BIASES_INIT_FILE),
        .NUM_FILTERS (NUM_FILTERS),
        .FILTER_SIZE (FILTER_SIZE),
        .PIPE_WIDTH (PIPE_WIDTH),
        .FRACTION (FRACTION),
        .POOL_SIZE (POOL_SIZE),
        .NEURON_WEIGHTS_INIT_FILE (NEURON_WEIGHTS_INIT_FILE),
        .NEURON_BIASES_INIT_FILE (NEURON_BIASES_INIT_FILE),
        .NUM_NEURONS (NUM_NEURONS),
        .SUBSAMPLE_FACTOR (SUBSAMPLE_FACTOR),
        .ADC_REF (ADC_REF),
        .SCALE_FACTOR (SCALE_FACTOR),
        .BIAS (BIAS)
    ) cnn1d (
        .clk    (clk),
        .rst    (rst),

        .cnn_ready_in   (cnn_ready_in),
        .cnn_valid_in   (cnn_valid_in),
        .cnn_data_in    (cnn_data_in),

        .cnn_ready_out  (cnn_ready_out),
        .cnn_condition  (cnn_condition)
    );

    int fd;
    int fd_wave;
    string line;
    bit valid;
    logic [DATA_WIDTH-1:0] hex;
    int count;

    initial begin
        count = 0;
        fd = $fopen("../../top/new_mr_lerp_x64.hex", "r");
        fd_wave = $fopen("scnn_sim_wave_new.csv", "w");
        $fwrite(fd_wave, "time_ns,voltage_ready_out,voltage_valid_out,voltage_data_out,relu_layer_ready_out,relu_layer_valid_out,cnn_ready_out,cnn_valid_out\n");
        cnn_ready_out = 1'b0;
        cnn_valid_in = 1'b0;
        cnn_data_in = {ADC_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        while (!$feof(fd)) begin
            #(CLK_PERIOD);
            $fwrite(fd_wave, "%0t,%d,%d,%f,%d,%d,%d,%d,%d\n",$time, cnn1d.voltage_ready_out,
                                                                    cnn1d.voltage_valid_out,
                                                                    cnn1d.voltage_data_out / $itor(2**FRACTION),
                                                                    cnn1d.relu_layer_ready_out,
                                                                    cnn1d.relu_layer_valid_out,
                                                                    cnn_ready_out,
                                                                    cnn1d.cnn_valid_out,
                                                                    cnn1d.tool_condition);
                                                                               
            //cnn_ready_out <= $urandom_range(1'b0, 1'b1);
            cnn_ready_out <= 1'b1;
            // if (count < 1) begin
            //     count++;
            //     cnn_valid_in <= 1'b0;
            // end else begin
            //     count = 0;
                if (cnn_ready_in | ~cnn_valid_in) begin
                    //valid = $urandom_range(1'b0, 1'b1);
                    valid = 1'b1;
                    $fgets(line, fd);
                    hex = line.atohex();
                    cnn_data_in <= hex;
                    cnn_valid_in <= valid;
                end
            //end

        end
        $fclose(fd);
        $fclose(fd_wave);
        $stop;
    end


endmodule