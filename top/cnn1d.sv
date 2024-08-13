// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on


module cnn1d (
    clk,
    rst,

    cnn_ready_in,
    cnn_valid_in,
    cnn_data_in,

    cnn_ready_out,
    cnn_condition
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 32;
    parameter CONV_WEIGHTS_INIT_FILE = "";
    parameter CONV_BIASES_INIT_FILE = "";
    parameter NUM_FILTERS = 32;
    parameter FILTER_SIZE = 5;
    parameter PIPE_WIDTH = 4;
    parameter FRACTION = 24; // position of the decimal point from the right 
    parameter POOL_SIZE = 256;
    parameter NEURON_WEIGHTS_INIT_FILE = "";
    parameter NEURON_BIASES_INIT_FILE = "";
    parameter NUM_NEURONS = 2;

    localparam NUM_INPUTS = NUM_FILTERS;
    localparam NUM_POOLS = NUM_INPUTS;
    localparam NEURON_INPUTS = NUM_POOLS;

    localparam NUM_FRACTION_LSBS = FRACTION;
    localparam NUM_FRACTION_MSBS = (DATA_WIDTH-FRACTION);
    /* FRACTION Example

        localparam DATA_WIDTH = 12;
        localparam FRACTION = 9;

        some_data = 12'b001000000000 = 0b001.000000000 = 0d1.0

    */
    
    // capture the entire possible width of a multiplier output (no truncation)
    localparam LPM_OUT_WIDTH = DATA_WIDTH * 2; 

    // where the MSB will be when computing a multiplication
    // from the MSB -: DATA_WIDTH to correctly truncate the data
    localparam LPM_OUT_MSB = (LPM_OUT_WIDTH - 1) - (DATA_WIDTH - FRACTION); 

    input logic clk;
    input logic rst;

    output logic cnn_ready_in;
    input logic cnn_valid_in;
    input logic [DATA_WIDTH-1:0] cnn_data_in;

    output logic cnn_condition;
    input logic cnn_ready_out;

    logic [0:NUM_NEURONS-1] cnn_valid_out;
    logic [DATA_WIDTH-1:0]  cnn_data_out [0:NUM_NEURONS-1];

    logic                   conv1d_layer_ready_out;
    logic [NUM_FILTERS-1:0] conv1d_layer_valid_out;
    logic [DATA_WIDTH-1:0]  conv1d_layer_data_out   [0:NUM_FILTERS-1];

    logic                   relu_layer_ready_out;
    logic [NUM_INPUTS-1:0]  relu_layer_valid_out;
    logic [DATA_WIDTH-1:0]  relu_layer_data_out     [0:NUM_INPUTS-1];

    logic                   gavgpool_layer_ready_out;
    logic [NUM_POOLS-1:0]   gavgpool_layer_valid_out;
    logic [DATA_WIDTH-1:0]  gavgpool_layer_data_out [0:NUM_POOLS-1];

    // synthesis translate_off
    typedef enum {
        NEW,
        WORN
    } condition_t;

    condition_t tool_condition;
    // synthesis translate_on

    conv1d_layer #(
        .DATA_WIDTH             (DATA_WIDTH),
        .WEIGHTS_INIT_FILE      (CONV_WEIGHTS_INIT_FILE),
        .BIASES_INIT_FILE       (CONV_BIASES_INIT_FILE),
        .NUM_FILTERS            (NUM_FILTERS),
        .FILTER_SIZE            (FILTER_SIZE),
        .PIPE_WIDTH             (PIPE_WIDTH),
        .FRACTION               (FRACTION)
    ) conv1d_layer (
        .clk                    (clk),
        .rst                    (rst),

        .conv1d_layer_valid_in  (cnn_valid_in),
        .conv1d_layer_ready_in  (cnn_ready_in),
        .conv1d_layer_data_in   (cnn_data_in),

        .conv1d_layer_ready_out (conv1d_layer_ready_out),
        .conv1d_layer_valid_out (conv1d_layer_valid_out),
        .conv1d_layer_data_out  (conv1d_layer_data_out)
    );

    activation_layer #(
        .ACTIVATION_FUNCTION        ("ReLU"),
        .DATA_WIDTH                 (DATA_WIDTH),
        .NUM_INPUTS                 (NUM_INPUTS)
    ) relu_layer (
        .clk                        (clk),
        .rst                        (rst),

        .activation_layer_ready_in  (conv1d_layer_ready_out),
        .activation_layer_valid_in  (conv1d_layer_valid_out),
        .activation_layer_data_in   (conv1d_layer_data_out),

        .activation_layer_ready_out (relu_layer_ready_out),
        .activation_layer_valid_out (relu_layer_valid_out),
        .activation_layer_data_out  (relu_layer_data_out)
    );

    gavgpool_layer #(
        .DATA_WIDTH                 (DATA_WIDTH),
        .POOL_SIZE                  (POOL_SIZE),
        .PIPE_WIDTH                 (PIPE_WIDTH),
        .NUM_POOLS                  (NUM_POOLS)
    ) gavgpool_layer (
        .clk                        (clk),
        .rst                        (rst),

        .gavgpool_layer_ready_in    (relu_layer_ready_out),
        .gavgpool_layer_valid_in    (relu_layer_valid_out),
        .gavgpool_layer_data_in     (relu_layer_data_out),

        .gavgpool_layer_ready_out   (gavgpool_layer_ready_out),
        .gavgpool_layer_valid_out   (gavgpool_layer_valid_out),
        .gavgpool_layer_data_out    (gavgpool_layer_data_out)
    );

    neuron_layer #(
        .DATA_WIDTH             (DATA_WIDTH),
        .WEIGHTS_INIT_FILE      (NEURON_WEIGHTS_INIT_FILE),
        .BIASES_INIT_FILE       (NEURON_BIASES_INIT_FILE),
        .NUM_NEURONS            (NUM_NEURONS),
        .NEURON_INPUTS          (NEURON_INPUTS),
        .PIPE_WIDTH             (PIPE_WIDTH),
        .FRACTION               (FRACTION)
    ) neuron_layer (
        .clk                    (clk),
        .rst                    (rst),

        .neuron_layer_ready_in  (gavgpool_layer_ready_out),
        .neuron_layer_valid_in  (gavgpool_layer_valid_out),
        .neuron_layer_data_in   (gavgpool_layer_data_out),

        .neuron_layer_ready_out (cnn_ready_out),
        .neuron_layer_valid_out (cnn_valid_out),
        .neuron_layer_data_out  (cnn_data_out)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            cnn_condition <= 1'b0;
        end else begin
            if (cnn_valid_out && cnn_ready_out) begin
                cnn_condition <= signed'(cnn_data_out[0]) < signed'(cnn_data_out[1]);
            end
        end
    end

    // synthesis translate_off
    assign tool_condition = cnn_condition ? WORN : NEW;
    // synthesis translate_on

endmodule