`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module conv1d_layer_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam WEIGHTS_INIT_FILE = "./MATLAB_weights_and_biases/conv1d_weights.hex";
    localparam BIASES_INIT_FILE = "./MATLAB_weights_and_biases/conv1d_biases.hex";
    localparam NUM_FILTERS = 32;
    localparam FILTER_SIZE = 5;
    localparam PIPE_WIDTH = 4;
    localparam FRACTION = 24; // position of the decimal point from the right 

    logic clk;
    logic rst;

    logic                   conv1d_layer_ready_in;
    logic                   conv1d_layer_valid_in;
    logic [DATA_WIDTH-1:0]  conv1d_layer_data_in;

    logic                   conv1d_layer_ready_out;
    logic [NUM_FILTERS-1:0] conv1d_layer_valid_out;
    logic [DATA_WIDTH-1:0]  conv1d_layer_data_out   [0:NUM_FILTERS-1];

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    conv1d_layer #(
        .DATA_WIDTH         (DATA_WIDTH),
        .WEIGHTS_INIT_FILE  (WEIGHTS_INIT_FILE),
        .BIASES_INIT_FILE   (BIASES_INIT_FILE),
        .NUM_FILTERS        (NUM_FILTERS),
        .FILTER_SIZE        (FILTER_SIZE),
        .PIPE_WIDTH         (PIPE_WIDTH),
        .FRACTION           (FRACTION)
    ) conv1d_layer (
        .clk    (clk),
        .rst    (rst),

        .conv1d_layer_ready_in   (conv1d_layer_ready_in),
        .conv1d_layer_valid_in   (conv1d_layer_valid_in),
        .conv1d_layer_data_in    (conv1d_layer_data_in),

        .conv1d_layer_ready_out  (conv1d_layer_ready_out),
        .conv1d_layer_valid_out  (conv1d_layer_valid_out),
        .conv1d_layer_data_out   (conv1d_layer_data_out)
    );

    initial begin
        conv1d_layer_data_in = {DATA_WIDTH{1'b0}};
        conv1d_layer_valid_in = 1'b0;
        conv1d_layer_ready_out = 1'b0;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        conv1d_layer_ready_out = 1'b1;
        conv1d_layer_valid_in = 1'b1;
        conv1d_layer_data_in = 32'hFFF73556;
        forever #1;
    end


endmodule