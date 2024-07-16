// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on

// really super simple ReLU activation function
module relu (
    clk,
    rst,

    a,
    o
);
    import cnn1d_pkg::*;
    
    input logic clk;
    input logic rst;

    input logic  [DATA_WIDTH-1:0] a;
    output logic [DATA_WIDTH-1:0] o;

    always_ff @(posedge clk) begin
        if (rst) begin
            o <= {DATA_WIDTH{1'b0}}; 
        end else begin
            // if the sign bit of the data is high it's negative, so send zero (neuron doesn't fire)
            // if the sign bit of the data is low it's positive, so send the data as-is
            o <= a[DATA_WIDTH-1] ? 12'd0 : a; 
        end
    end

endmodule