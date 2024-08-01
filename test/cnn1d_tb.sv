`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module cnn1d_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam CONV_WEIGHTS_INIT_FILE = "./MATLAB_weights_and_biases/conv1d_weights.hex";
    localparam CONV_BIASES_INIT_FILE = "./MATLAB_weights_and_biases/conv1d_biases.hex";
    localparam NUM_FILTERS = 32;
    localparam FILTER_SIZE = 5;
    localparam PIPE_WIDTH = 4;
    localparam FRACTION = 24; // position of the decimal point from the right 
    localparam POOL_SIZE = 250;
    localparam NEURON_WEIGHTS_INIT_FILE = "./MATLAB_weights_and_biases/fc_weights.hex";
    localparam NEURON_BIASES_INIT_FILE = "./MATLAB_weights_and_biases/fc_biases.hex";
    localparam NUM_NEURONS = 2;


    logic clk;
    logic rst;

    logic cnn_ready_in;
    logic cnn_valid_in;
    logic [DATA_WIDTH-1:0] cnn_data_in;

    logic cnn_ready_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    cnn1d #(
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
        .NUM_NEURONS (NUM_NEURONS)
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
    string line;
    bit valid;
    logic [DATA_WIDTH-1:0] hex;

    initial begin
        fd = $fopen("./worn_cutting_tool_samples.hex", "r");
        cnn_ready_out = 1'b0;
        cnn_valid_in = 1'b0;
        cnn_data_in = {DATA_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        while (!$feof(fd)) begin
            #(CLK_PERIOD);

            //cnn_ready_out <= $urandom_range(1'b0, 1'b1);
            cnn_ready_out <= 1'b1;
            if (cnn_ready_in | ~cnn_valid_in) begin
                //valid = $urandom_range(1'b0, 1'b1);
                valid = 1'b1;
                $fgets(line, fd);
                hex = line.atohex();
                cnn_data_in <= hex;
                cnn_valid_in <= valid;
            end
        end
        $fclose(fd);
        $stop;
    end


endmodule