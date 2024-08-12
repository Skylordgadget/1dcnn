// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on

module adc2v (
    clk,
    rst,

    adc_ready_in,
    adc_valid_in,
    adc_data_in,

    voltage_ready_out,
    voltage_valid_out,
    voltage_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 32;
    // position of the decimal point from the right 
    parameter FRACTION  = 20; 
    parameter PIPE_WIDTH = 4;

    localparam FRACTIONAL_BITS = FRACTION;
    localparam INTEGER_BITS = (DATA_WIDTH-FRACTION);

    // Fun magic numbers :-) (this is bad but I will fix this later) -Harry
    localparam MAGIC_CONVERSION = 32'h0009c400;
    localparam BIAS = 12'hb1e;

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

    localparam TOTAL_PIPE_WIDTH = PIPE_WIDTH + 1;

    input logic clk;
    input logic rst;

    output logic                    adc_ready_in;
    input logic                     adc_valid_in;
    input logic [ADC_WIDTH-1:0]     adc_data_in;

    input logic                     voltage_ready_out;
    output logic                    voltage_valid_out;
    output logic [DATA_WIDTH-1:0]   voltage_data_out;

    logic [TOTAL_PIPE_WIDTH-1:0] valid_pipe;
    logic [LPM_OUT_WIDTH-1:0] mult_out, bias;

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_pipe <= {TOTAL_PIPE_WIDTH{1'b0}};
        end else begin
            if (adc_ready_in) begin
                valid_pipe <= {valid_pipe[TOTAL_PIPE_WIDTH-2:0], adc_valid_in};
            end
        end
    end 

    // multiplier
    mult #( 
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) multiplier (
        .clken  (adc_ready_in), // only clock data when ready is high
        .clock  (clk),
        .dataa  ({{(DATA_WIDTH-ADC_WIDTH){1'b0}}, adc_data_in}),
        .datab  (MAGIC_CONVERSION),
        .result (mult_out)
    );


    always_ff @(posedge clk) begin
        if (rst) begin
            bias <= {LPM_OUT_WIDTH{1'b0}};
        end else begin
            if (adc_ready_in) begin
                bias <= mult_out + {{DATA_WIDTH{1'b1}}, BIAS, {FRACTION{1'b0}}};
            end
        end
    end
 
    assign voltage_data_out = bias[DATA_WIDTH-1:0];
    assign voltage_valid_out = valid_pipe[TOTAL_PIPE_WIDTH-1];
    assign adc_ready_in = ~voltage_valid_out | voltage_ready_out;


endmodule