// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
// synthesis translate_on

module xor_net (
    clk,
    rst,

    a,
    b, 

    o
);
    import cnn1d_pkg::*;

    input logic clk;
    input logic rst;

    input logic [DATA_WIDTH-1:0] a;
    input logic [DATA_WIDTH-1:0] b;

    output logic [DATA_WIDTH-1:0] o;

    logic [DATA_WIDTH-1:0] input_1 [0:1];
    logic [DATA_WIDTH-1:0] input_2 [0:1];

    logic [DATA_WIDTH-1:0] weights_1 [0:1];
    logic [DATA_WIDTH-1:0] weights_2 [0:1];
    logic [DATA_WIDTH-1:0] weights_3 [0:1];

    logic [DATA_WIDTH-1:0] bias_1;
    logic [DATA_WIDTH-1:0] bias_2;
    logic [DATA_WIDTH-1:0] bias_3;

    logic [DATA_WIDTH-1:0] connections [0:1];

    always_ff @(posedge clk) begin
        input_1[0] <= a;
        input_1[1] <= b;

        input_2[0] <= b;
        input_2[1] <= a;

        bias_1 <= 12'b000000000000;
        weights_1[0] <= 12'b001000000000;
        weights_1[1] <= 12'b001000000000;

        bias_2 <= 12'b111000000000;
        weights_2[0] <= 12'b001000000000;
        weights_2[1] <= 12'b001000000000;

        bias_3 <= 12'b000000000000;
        weights_3[0] <= 12'b001000000000;
        weights_3[1] <= 12'b110000000000;
    end

    neuron #(
        .NUM_INPUTS(2)
    ) hidden_1 (
        .clk    (clk),
        .rst    (rst),

        .a      (input_1),
        .w      (weights_1),

        .bias   (bias_1),
        .o      (connections[0])
    );


    neuron #(
        .NUM_INPUTS(2)
    ) hidden_2 (
        .clk    (clk),
        .rst    (rst),

        .a      (input_2),
        .w      (weights_2),

        .bias   (bias_2),
        .o      (connections[1])
    );


    neuron #(
        .NUM_INPUTS(2)
    ) neuron_out (
        .clk    (clk),
        .rst    (rst),

        .a      (connections),
        .w      (weights_3),

        .bias   (bias_3),
        .o      (o)
    );

endmodule