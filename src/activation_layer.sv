////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       activation_layer.sv                                       //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Parameterised activation layer with AXI interface.        //
//                                                                            //
//                  The user may choose the type of activation function and   //
//                  define the number of inputs.                              //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on

module activation_layer (
    clk,
    rst,

    activation_layer_ready_in,
    activation_layer_valid_in,
    activation_layer_data_in,

    activation_layer_ready_out,
    activation_layer_valid_out,
    activation_layer_data_out
);

    import cnn1d_pkg::*;
    
    parameter ACTIVATION_FUNCTION = "ReLU";
    parameter DATA_WIDTH = 12; // width of the incoming data    
    parameter NUM_INPUTS = 5;

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    activation_layer_ready_in;
    input logic [NUM_INPUTS-1:0]    activation_layer_valid_in;
    input logic [DATA_WIDTH-1:0]    activation_layer_data_in    [0:NUM_INPUTS-1];

    // axi output interface
    input logic                     activation_layer_ready_out;
    output logic [NUM_INPUTS-1:0]   activation_layer_valid_out;
    output logic [DATA_WIDTH-1:0]   activation_layer_data_out   [0:NUM_INPUTS-1];    

    // private signals
    logic [NUM_INPUTS-1:0] activation_ready_in;

    generate 
        genvar i;
        if (ACTIVATION_FUNCTION == "ReLU") begin
            // if all the activators are ready then the global activation layer is ready
            assign activation_layer_ready_in = &activation_ready_in;

            for (i=0; i<NUM_INPUTS; i++) begin: RELU
                relu #(
                    .DATA_WIDTH     (DATA_WIDTH)
                ) relu (
                    .clk            (clk),
                    .rst            (rst),

                    .relu_ready_in  (activation_ready_in[i]),
                    .relu_valid_in  (activation_layer_valid_in[i]),
                    .relu_data_in   (activation_layer_data_in[i]),
                    
                    .relu_ready_out (activation_layer_ready_out),
                    .relu_valid_out (activation_layer_valid_out[i]),
                    .relu_data_out  (activation_layer_data_out[i])
                );
            end

        end else begin
            assign activation_layer_ready_in = activation_layer_ready_out;

            for (i=0; i<NUM_INPUTS; i++) begin: PASSTHROUGH
                assign activation_layer_data_out[i] = activation_layer_data_in[i];
                assign activation_layer_valid_out[i] = activation_layer_valid_in[i];
            end           
        end
    endgenerate

endmodule