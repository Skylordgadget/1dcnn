// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
// synthesis translate_on

module xor_net (
    clk,
    rst,

    xor_net_ready_in,
    xor_net_valid_in,
    xor_net_data_in,

    xor_net_ready_out,
    xor_net_valid_out,
    xor_net_data_out
);
    import cnn1d_pkg::*;

    localparam NUM_INPUTS = 2;

    input logic clk;
    input logic rst;

    output logic    [NUM_INPUTS-1:0]    xor_net_ready_in;
    input logic     [NUM_INPUTS-1:0]    xor_net_valid_in;
    input logic     [DATA_WIDTH-1:0]    xor_net_data_in     [0:NUM_INPUTS-1];

    input logic                         xor_net_ready_out;
    output logic                        xor_net_valid_out;
    output logic    [DATA_WIDTH-1:0]    xor_net_data_out;

    logic [DATA_WIDTH-1:0] hidden_layer_weights [0:NUM_INPUTS-1][0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] output_layer_weights [0:NUM_INPUTS-1];

    logic [DATA_WIDTH-1:0] hidden_layer_biases [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] output_layer_bias;

    logic [DATA_WIDTH-1:0] hidden_layer_data_out [0:NUM_INPUTS-1];
    logic                  hidden_layer_ready_out;
    logic [NUM_INPUTS-1:0] hidden_layer_valid_out;

    always_ff @(posedge clk) begin
        hidden_layer_weights[0][0] <= 12'b001000000000;
        hidden_layer_weights[0][1] <= 12'b001000000000;
        hidden_layer_weights[1][0] <= 12'b001000000000;
        hidden_layer_weights[1][1] <= 12'b001000000000;
    
        hidden_layer_biases[0] <= 12'b000000000000;
        hidden_layer_biases[1] <= 12'b111000000000;

        output_layer_weights[0] <= 12'b001000000000;
        output_layer_weights[1] <= 12'b110000000000;

        output_layer_bias <= 12'b000000000000;
    end


    generate 
        genvar n;
        for (n=0; n<NUM_INPUTS; n++) begin: HIDDEN_LAYER
            neuron #(
                .NUM_INPUTS(NUM_INPUTS)
            ) hidden_layer (
                .clk    (clk),
                .rst    (rst),

                .neuron_ready_in    (xor_net_ready_in[n]),
                .neuron_valid_in    (xor_net_valid_in[n]),
                .neuron_data_in     (xor_net_data_in),

                .neuron_weights     (hidden_layer_weights[n]),
                .neuron_bias        (hidden_layer_biases[n]),

                .neuron_ready_out   (hidden_layer_ready_out),
                .neuron_valid_out   (hidden_layer_valid_out[n]),
                .neuron_data_out    (hidden_layer_data_out[n])  
            );
        end
    endgenerate


    neuron #(
        .NUM_INPUTS(NUM_INPUTS)
    ) output_layer (
        .clk    (clk),
        .rst    (rst),

        .neuron_ready_in    (hidden_layer_ready_out),
        .neuron_valid_in    (&hidden_layer_valid_out), // AND reduce valid signal
        .neuron_data_in     (hidden_layer_data_out),

        .neuron_weights     (output_layer_weights),
        .neuron_bias        (output_layer_bias),

        .neuron_ready_out   (xor_net_ready_out),
        .neuron_valid_out   (xor_net_valid_out),
        .neuron_data_out    (xor_net_data_out)  
    );

endmodule