// synopsys translate_off
`timescale 1ns / 1ns
// synopsys translate_on

package cnn1d_pkg;
    localparam ADC_WIDTH = 12;
    localparam MAX_ADC_VALUE = 2**12;
    localparam M10_DEV_KIT_BUTTONS = 4;
    localparam M10_DEV_KIT_LEDS = 5;

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

    localparam ADC_WIDTH_CLOG2 = clog2(ADC_WIDTH);
	 localparam ADC_CHANNEL_WIDTH = 5;

    // precomputed factorials for exp module
    localparam SUPPORTED_PRECISION = 10;
    
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