`timescale 1ns / 1ns

package cnn1d_pkg;
    localparam LPM_PIPE_WIDTH = 4;
    localparam DATA_WIDTH = 12; // width of the all the fixed-point data in the system
    localparam FRACTION = 6; // position of the decimal point from the right 
    localparam SUPPORTED_PRECISION = 10;
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

    // simple clog2 for computing the minimum number of bits required for certain registers
    function integer clog2;
        input [31:0] value;
        integer i;
        begin
            clog2 = 32;
            for(i=31; i>0; i--) begin
                if (2**i >= value) begin
                    clog2 = i;
                end
            end
        end
    endfunction


    // precomputed factorials for exp module
    
    
    localparam FACTORIAL_1 = 1;
    localparam FACTORIAL_2 = 2;
    localparam FACTORIAL_3 = 6;
    localparam FACTORIAL_4 = 24;
    localparam FACTORIAL_5 = 120;
    localparam FACTORIAL_6 = 720;
    localparam FACTORIAL_7 = 5040;
    localparam FACTORIAL_8 = 40320;
    localparam FACTORIAL_9 = 362880;
    localparam FACTORIAL_10 = 3628800;

endpackage