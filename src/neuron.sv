////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       neuron.sv                                                 //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Basic implementation of a neuron with an AXI interface.   //
//                                                                            //
//                  The neuron takes NUM_INPUTS and multiplies each with      //
//                  their respective weight from 'neuron_weights'. The result //
//                  from each multiplication is accumulated and 'neuron_bias' //
//                  is applied. The current implementation uses a single      //
//                  multiplier to save resources.                             //
//  TODO:           - Add options for number of multipliers                   //
//                  - Decouple activation function from core                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
// synthesis translate_on

module neuron (
    clk,
    rst,

    neuron_ready_in,
    neuron_valid_in,
    neuron_data_in,

    neuron_weights,
    neuron_bias,

    neuron_ready_out,
    neuron_valid_out,
    neuron_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH    = 12; // width of the incoming data
    parameter NUM_INPUTS    = 1; 
    parameter PIPE_WIDTH    = 4;
    parameter FRACTION      = 24;

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
    
    localparam INPUT_WIDTH = clog2(NUM_INPUTS);
    localparam MULT_OUT_WIDTH = (DATA_WIDTH * 2); 

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    neuron_ready_in;
    input logic                     neuron_valid_in;
    input logic [DATA_WIDTH-1:0]    neuron_data_in      [0:NUM_INPUTS-1];

    // static input registers
    input logic [DATA_WIDTH-1:0]    neuron_weights      [0:NUM_INPUTS-1];
    input logic [DATA_WIDTH-1:0]    neuron_bias;

    // axi output interface
    input logic                     neuron_ready_out;
    output logic                    neuron_valid_out;
    output logic [DATA_WIDTH-1:0]   neuron_data_out;

    // private signals
    logic                       p2s_ready_out;
    logic                       p2s_valid_out;
    logic [DATA_WIDTH-1:0]      p2s_serial_out;

    logic [INPUT_WIDTH-1:0]     weight_select;

    logic                       mult_reduce_ready_out;
    logic                       mult_reduce_valid_out;
    logic [MULT_OUT_WIDTH-1:0]  mult_reduce_result_out;
    
    logic                       relu_ready_in;
    logic                       relu_valid_in;
    logic [DATA_WIDTH-1:0]      relu_data_in;

    logic                       relu_ready_out;
    logic                       relu_valid_out;
    logic [DATA_WIDTH-1:0]      relu_data_out; 

    /* parallel to serial converter
    a p2s is required as the core is designed to use a single multipler 
    TODO when the core supports multiple multipliers this will need to scale
    the number of sequential outputs based on the number of multipliers*/
    p2s #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_ELEMENTS (NUM_INPUTS)
    ) parallel_to_serial (
        .clk            (clk),
        .rst            (rst),

        .p2s_ready_in   (neuron_ready_in),
        .p2s_valid_in   (neuron_valid_in),
        .p2s_parallel_in(neuron_data_in),

        .p2s_ready_out  (p2s_ready_out),
        .p2s_valid_out  (p2s_valid_out),
        .p2s_serial_out (p2s_serial_out)
    );

    // simple counter to select the weights from the neuron_weights register
    always_ff @(posedge clk) begin
        if (rst) begin
            weight_select <= {INPUT_WIDTH{1'b0}};
        end else begin
            if (p2s_ready_out && p2s_valid_out) begin
                if (weight_select < NUM_INPUTS-1) begin
                    weight_select <= weight_select + 1'b1;
                end else begin
                    weight_select <= {INPUT_WIDTH{1'b0}};
                end
            end
        end
    end

    /* multiply reduce (multiply accumulate)
    takes the inputs, multiplies them with their respective weight and adds the 
    result to an accumulator. The accumulator is reset when all the inputs have
    been processed */
    mult_reduce #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_ELEMENTS (NUM_INPUTS),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) multiply_reduce (
        .clk                    (clk),
        .rst                    (rst),

        .mult_reduce_ready_in   (p2s_ready_out),
        .mult_reduce_valid_in   (p2s_valid_out),
        .mult_reduce_dataa_in   (p2s_serial_out),
        .mult_reduce_datab_in   (neuron_weights[weight_select]),

        .mult_reduce_ready_out  (mult_reduce_ready_out),
        .mult_reduce_valid_out  (mult_reduce_valid_out),
        .mult_reduce_result_out (mult_reduce_result_out)
    );
    
    assign mult_reduce_ready_out = relu_ready_in;
    assign relu_valid_in = mult_reduce_valid_out;
    // part select the multiplier output
    assign relu_data_in = mult_reduce_result_out[LPM_OUT_MSB-:DATA_WIDTH] + neuron_bias;

    // activation function (ReLU)
    // TODO remove this from neuron.sv
    relu #(
        .DATA_WIDTH (DATA_WIDTH)
    ) activation (
        .clk    (clk),
        .rst    (rst),

        .relu_ready_in   (relu_ready_in),
        .relu_valid_in   (relu_valid_in),
        .relu_data_in    (relu_data_in),
        
        .relu_ready_out  (relu_ready_out),
        .relu_valid_out  (relu_valid_out),
        .relu_data_out   (relu_data_out)
     );

    assign relu_ready_out = ~neuron_valid_out | neuron_ready_out;

    // AXI logic to ensure the data is captured by the output
    always_ff @(posedge clk) begin
        if (rst) begin
            neuron_valid_out <= 1'b0;
            neuron_data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            if (relu_valid_out && relu_ready_out) begin
                neuron_data_out <= relu_data_out;
                neuron_valid_out <= 1'b1;
            end 

            if (neuron_valid_out && neuron_ready_out) begin
                neuron_valid_out <= 1'b0;
            end
        end
    end

endmodule