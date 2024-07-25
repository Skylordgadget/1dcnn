////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       conv1d.sv                                                 //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Basic 1-dimensional convoltion with a variable kernel     //
//                  size.                                                     //
//                                                                            //
//                  Takes a sequential stream of data and convolves it with   //
//                  'conv1d_weights'. This implementation uses a single       //
//                  multiplier to save on resources and is AXI compliant.     //
//                  It applies causal padding.                                //
//  TODO:           - Add options for padding, stride and number of           //
//                    multipliers                                             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
`include "./../ip/sp_ram.v"
// synthesis translate_on


module conv1d (
    clk,
    rst,

    conv1d_ready_in,
    conv1d_valid_in,
    conv1d_data_in,

    conv1d_weights,
    conv1d_bias,

    conv1d_ready_out,
    conv1d_valid_out,
    conv1d_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 12; // width of the incoming data
    parameter FILTER_SIZE = 5; 
    parameter PIPE_WIDTH = 4;

    localparam KERNEL_WIDTH = clog2(FILTER_SIZE);
    localparam MULT_OUT_WIDTH = (DATA_WIDTH * 2); 

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    conv1d_ready_in;
    input logic                     conv1d_valid_in;
    input logic [DATA_WIDTH-1:0]    conv1d_data_in;

    // static input registers
    input logic [DATA_WIDTH-1:0]    conv1d_weights [0:FILTER_SIZE-1];
    input logic [DATA_WIDTH-1:0]    conv1d_bias;
    
    // axi output interface
    input logic                     conv1d_ready_out;
    output logic                    conv1d_valid_out;
    output logic [DATA_WIDTH-1:0]   conv1d_data_out;

    // private signals
    logic                       p2s_valid_in;
    logic [DATA_WIDTH-1:0]      conv1d_kernel [0:FILTER_SIZE-1];

    logic                       p2s_ready_out;
    logic                       p2s_valid_out;
    logic [DATA_WIDTH-1:0]      p2s_serial_out;

    logic [KERNEL_WIDTH-1:0]    weight_select;
    
    logic                       mult_reduce_ready_out;
    logic                       mult_reduce_valid_out;
    logic [MULT_OUT_WIDTH-1:0]  mult_reduce_result_out;
    
    logic                       relu_ready_in;
    logic                       relu_valid_in;
    logic [DATA_WIDTH-1:0]      relu_data_in;

    logic                       relu_ready_out;
    logic                       relu_valid_out;
    logic [DATA_WIDTH-1:0]      relu_data_out; 


	integer i, j;
    always_ff @(posedge clk) begin
        if (rst) begin
            /* initialise the kernal to all zeros
            when the first beat of valid data enters the kernel the 
            convolution process begins (causal padding) 
            e.g., 
            KERNEL_WIDTH = 5;

            valid = 1;
            kernel = [0, 0, 0, 0, first_data_beat];
            ...
            valid = 1;
            kernel = [0, 0, 0, first_data_beat, second_data_beat];
            */
            p2s_valid_in <= 1'b0;
            for (i=0; i<FILTER_SIZE; i++) begin
                conv1d_kernel[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            if (conv1d_ready_in) begin
                p2s_valid_in <= conv1d_valid_in;
                if (conv1d_valid_in) begin
                    // shift the input data along the kernel only when ready is high
                    for (j=FILTER_SIZE-1; j>0; j--) begin
                        conv1d_kernel[j] <= conv1d_kernel[j-1];
                        conv1d_kernel[0] <= conv1d_data_in;
                    end
                end
            end 
        end
    end


    /* parallel to serial converter
    a p2s is required as the core is designed to use a single multipler 
    TODO when the core supports multiple multipliers this will need to scale
    the number of sequential outputs based on the number of multipliers*/
    p2s #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_ELEMENTS (FILTER_SIZE)
    ) parallel_to_serial (
        .clk            (clk),
        .rst            (rst),

        .p2s_ready_in   (conv1d_ready_in),
        .p2s_valid_in   (p2s_valid_in),
        .p2s_parallel_in(conv1d_kernel),

        .p2s_ready_out  (p2s_ready_out),
        .p2s_valid_out  (p2s_valid_out),
        .p2s_serial_out (p2s_serial_out)
    );

    // simple counter to select the weights from the 1dconv_weights register
    always_ff @(posedge clk) begin
        if (rst) begin
            weight_select <= {KERNEL_WIDTH{1'b0}};
        end else begin
            if (p2s_ready_out && p2s_valid_out) begin
                if (weight_select < FILTER_SIZE-1) begin
                    weight_select <= weight_select + 1'b1;
                end else begin
                    weight_select <= {KERNEL_WIDTH{1'b0}};
                end
            end
        end
    end

    /* multiply reduce (multiply accumulate)
    takes the incoming sequential kernel stream, multiplies each element with
    it's respective weight and adds the value to an accumulator. The accumulator
    is reset when all the elements in a filter have been processed */
    mult_reduce #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_ELEMENTS (FILTER_SIZE),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) multiply_reduce (
        .clk                    (clk),
        .rst                    (rst),

        .mult_reduce_ready_in   (p2s_ready_out),
        .mult_reduce_valid_in   (p2s_valid_out),
        .mult_reduce_dataa_in   (p2s_serial_out),
        .mult_reduce_datab_in   (conv1d_weights[weight_select]),

        .mult_reduce_ready_out  (mult_reduce_ready_out),
        .mult_reduce_valid_out  (mult_reduce_valid_out),
        .mult_reduce_result_out (mult_reduce_result_out)
    );
    

    assign mult_reduce_ready_out = relu_ready_in;
    assign relu_valid_in = mult_reduce_valid_out;
    // part select the multiplier output
    assign relu_data_in = mult_reduce_result_out[LPM_OUT_MSB-:DATA_WIDTH] + conv1d_bias;

    // activation function (ReLU)
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

    assign relu_ready_out = ~conv1d_valid_out | conv1d_ready_out;

    // AXI logic to ensure the data is captured by the output
    always_ff @(posedge clk) begin
        if (rst) begin
            conv1d_valid_out <= 1'b0;
            conv1d_data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            if (relu_valid_out && relu_ready_out) begin
                conv1d_data_out <= relu_data_out;
                conv1d_valid_out <= 1'b1;
            end 

            if (conv1d_valid_out && conv1d_ready_out) begin
                conv1d_valid_out <= 1'b0;
            end
        end
    end


endmodule