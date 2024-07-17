// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on

// really super simple ReLU activation function
module relu (
    clk,
    rst,

    relu_ready_in,
    relu_valid_in,
    relu_data_in,

    relu_ready_out,
    relu_valid_out,
    relu_data_out
);
    import cnn1d_pkg::*;
    
    input logic clk;
    input logic rst;

    output logic                        relu_ready_in;
    input logic                         relu_valid_in;
    input logic     [DATA_WIDTH-1:0]    relu_data_in;

    input logic                         relu_ready_out;
    output logic                        relu_valid_out;
    output logic    [DATA_WIDTH-1:0]    relu_data_out;


    always_ff @(posedge clk) begin
        if (rst) begin
            relu_valid_out <= 1'b0;
            relu_data_out <= {DATA_WIDTH{1'b0}}; 
        end else begin
            // if the sign bit of the data is high it's negative, so send zero (neuron doesn't fire)
            // if the sign bit of the data is low it's positive, so send the data as-is
            if (relu_ready_in) begin
                relu_valid_out <= relu_valid_in;
                relu_data_out <= relu_data_in[DATA_WIDTH-1] ? 12'd0 : relu_data_in; 
            end
        end
    end

    assign relu_ready_in = rst ? 1'b0 : relu_ready_out | ~relu_valid_in;

endmodule