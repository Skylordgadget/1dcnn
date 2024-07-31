`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module neuron_layer_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam WEIGHTS_INIT_FILE = "./MATLAB_weights_and_biases/fc_weights.hex";
    localparam BIASES_INIT_FILE = "./MATLAB_weights_and_biases/fc_biases.hex";
    localparam NUM_NEURONS = 2;
    localparam NEURON_INPUTS = 32;
    localparam PIPE_WIDTH = 4;
    localparam FRACTION = 24; // position of the decimal point from the right 

    logic clk;
    logic rst;

    logic                   neuron_layer_ready_in;
    logic                   neuron_layer_valid_in;
    logic [DATA_WIDTH-1:0]  neuron_layer_data_in [0:NEURON_INPUTS-1];

    logic                   neuron_layer_ready_out;
    logic [NUM_NEURONS-1:0] neuron_layer_valid_out;
    logic [DATA_WIDTH-1:0]  neuron_layer_data_out   [0:NUM_NEURONS-1];

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    neuron_layer #(
        .DATA_WIDTH         (DATA_WIDTH),
        .WEIGHTS_INIT_FILE  (WEIGHTS_INIT_FILE),
        .BIASES_INIT_FILE   (BIASES_INIT_FILE),
        .NUM_NEURONS        (NUM_NEURONS),
        .NEURON_INPUTS        (NEURON_INPUTS),
        .PIPE_WIDTH         (PIPE_WIDTH),
        .FRACTION           (FRACTION)
    ) neuron_layer (
        .clk    (clk),
        .rst    (rst),

        .neuron_layer_ready_in   (neuron_layer_ready_in),
        .neuron_layer_valid_in   (neuron_layer_valid_in),
        .neuron_layer_data_in    (neuron_layer_data_in),

        .neuron_layer_ready_out  (neuron_layer_ready_out),
        .neuron_layer_valid_out  (neuron_layer_valid_out),
        .neuron_layer_data_out   (neuron_layer_data_out)
    );

    initial begin
        for (int i=0; i<NEURON_INPUTS; i++) begin
            neuron_layer_data_in[i] = {DATA_WIDTH{1'b0}};
        end
        neuron_layer_valid_in = 1'b0;
        neuron_layer_ready_out = 1'b0;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        neuron_layer_ready_out = 1'b1;
        neuron_layer_valid_in = 1'b1;
        for (int i=0; i<NEURON_INPUTS; i++) begin
            neuron_layer_data_in[i] = {i[7:0],24'd0};
        end
        
        forever #1;
    end


endmodule