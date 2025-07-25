`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module m10_cnn1d_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 24;
    localparam FRACTION = 12; // position of the decimal point from the right 
    localparam PIPE_WIDTH = 4;
  
    localparam SUBSAMPLE_FACTOR = 250;
    
    localparam CONV_BIASES_INIT_FILE = "../weights/conv1d_1_biases_12I12F.hex";
    localparam CONV_WEIGHTS_INIT_FILE = "../weights/conv1d_1_weights_12I12F.hex";
    localparam NUM_FILTERS = 8;
    localparam FILTER_SIZE = 4;
    
    localparam POOL_SIZE = 512;

    localparam FC_1_INPUTS  = 8;
    localparam FC_1_NEURONS = 8; 
    localparam FC_1_PARAMS  = "../weights/fc_parameters_1_12I12F.hex";
    localparam FC_2_INPUTS  = 8;
    localparam FC_2_NEURONS = 2;
    localparam FC_2_PARAMS  = "../weights/fc_parameters_2_12I12F.hex";

    logic clk;
    logic rst;

    logic cnn_ready_in;
    logic cnn_valid_in;
    logic [ADC_WIDTH-1:0] cnn_data_in [0:1];

    logic cnn_ready_out;
    logic cnn_valid_out;
    logic cnn_condition;

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

        .FC_1_INPUTS (FC_1_INPUTS),
        .FC_1_NEURONS (FC_1_NEURONS),
        .FC_1_PARAMS (FC_1_PARAMS),
        .FC_2_INPUTS (FC_2_INPUTS),
        .FC_2_NEURONS (FC_2_NEURONS),
        .FC_2_PARAMS (FC_2_PARAMS),

        .SUBSAMPLE_FACTOR (SUBSAMPLE_FACTOR)
    ) cnn1d (
        .clk    (clk),
        .rst    (rst),

        .cnn_ready_in   (cnn_ready_in),
        .cnn_valid_in   (cnn_valid_in),
        .cnn_data_in    (cnn_data_in),

        .cnn_ready_out  (cnn_ready_out),
        .cnn_valid_out  (cnn_valid_out),
        .cnn_condition  (cnn_condition)
    );

    int fd_1;
    int fd_2;
    int fd_wave;
    string line;
    bit valid;
    logic [ADC_WIDTH-1:0] hex;
    int count;

    initial begin
        count = 0;
        fd_1 = $fopen("../../top/new_lerp_ch1.hex", "r");
        fd_2 = $fopen("../../top/new_lerp_ch3.hex", "r");
        //fd_wave = $fopen("scnn_sim_wave_new.csv", "w");
        //$fwrite(fd_wave, "time_ns,voltage_ready_out,voltage_valid_out,voltage_data_out,relu_layer_ready_out,relu_layer_valid_out,cnn_ready_out,cnn_valid_out\n");
        cnn_ready_out = 1'b0;
        cnn_valid_in = 1'b0;
        cnn_data_in[0] = {ADC_WIDTH{1'b0}};
        cnn_data_in[1] = {ADC_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        while (!$feof(fd_1) && !$feof(fd_2)) begin
            #(CLK_PERIOD);
            // $fwrite(fd_wave, "%0t,%d,%d,%f,%d,%d,%d,%d,%d\n",$time, cnn1d.voltage_ready_out,
            //                                                         cnn1d.voltage_valid_out,
            //                                                         cnn1d.voltage_data_out / $itor(2**FRACTION),
            //                                                         cnn1d.relu_layer_ready_out,
            //                                                         cnn1d.relu_layer_valid_out,
            //                                                         cnn_ready_out,
            //                                                         cnn1d.cnn_valid_out,
            //                                                         cnn1d.tool_condition);
                                                                               
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
                    $fgets(line, fd_1);
                    hex = line.atohex();
                    cnn_data_in[0] <= hex;

                    $fgets(line, fd_2);
                    hex = line.atohex();
                    cnn_data_in[1] <= hex;

                    cnn_valid_in <= valid;
                end
            //end

        end
        $fclose(fd_1);
        $fclose(fd_2);
        //$fclose(fd_wave);
        $stop;
    end


endmodule