`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"

module softmax (
    clk,
    rst,

    valid_in,
    ready_in,
    data_in,

    valid_out,
    ready_out,
    data_out
);
    import cnn1d_pkg::*;
    
    parameter NUM_INPUTS = 2;

    

endmodule
