`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module neuron_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam NUM_INPUTS = 1;

    logic clk;
    logic rst;

    logic neuron_ready_in;
    logic neuron_valid_in;
    logic [DATA_WIDTH-1:0] neuron_data_in [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] neuron_weights [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] neuron_bias;
    
    logic neuron_ready_out;
    logic neuron_valid_out;
    logic [DATA_WIDTH-1:0] neuron_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    neuron #(
        .NUM_INPUTS (NUM_INPUTS)
    ) neuron (
        .clk    (clk),
        .rst    (rst),

        .neuron_ready_in    (neuron_ready_in),
        .neuron_valid_in    (neuron_valid_in),
        .neuron_data_in     (neuron_data_in),

        .neuron_weights     (neuron_weights),
        .neuron_bias        (neuron_bias),

        .neuron_ready_out   (neuron_ready_out),
        .neuron_valid_out   (neuron_valid_out),
        .neuron_data_out    (neuron_data_out)
    );

    initial begin
        neuron_ready_out = 1'b0;
        neuron_valid_in = 1'b0;
        for (int i=0; i<NUM_INPUTS; i++) begin
            neuron_data_in[i] = 0;
            neuron_weights[i] = 0;
        end
        neuron_bias = 0;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        #20;
        neuron_ready_out = 1'b1;
        neuron_valid_in = 1'b1;
        for (int i=0; i<NUM_INPUTS; i++) begin
            neuron_data_in[i] = (i+1)*5;
            neuron_weights[i] = (i+1)*-5;
        end
        neuron_bias = 5;
        #4;
        #100;
    end


endmodule