////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       pow.sv                                                    //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Computes the 'pow_data_in' to the power of 'POW' using    //
//                  LPM_MULT blocks.                                          //
//                  I.e., pow_data_out = pow_data_in ** POW.                  //
//                                                                            //
//                  This implementation is only designed for powers between   //
//                  2 and 10. Any less or more and it doesn't work.           //
//                                                                            //
//                  It works by cascading an additional multiplier for every  //
//                  power after 2. However, it does not cascade multipliers   //
//                  for optimal speed.                                        //
//  TODO:           - Allow powers greater than 10                            //
//                  - Optimise cascading for speed                            //
//                  - 16/07/24 to optimise the cascading take the remainder   //
//                    of the number of multipliers to know if you need a      //
//                    final stage                                             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// this module is unused as of 03/08/2024

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
// synthesis translate_on

module pow (
    clk,
    rst,

    pow_ready_in,
    pow_valid_in,
    pow_data_in,
    
    pow_ready_out,
    pow_valid_out,
    pow_data_out
);
    import cnn1d_pkg::*;

    parameter POW = 2; // pow_data_out = pow_data_in ** POW
    parameter DATA_WIDTH = 32;
    parameter LPM_PIPE_WIDTH = 4;
    parameter FRACTION = 24;

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
    
    /* one multipier is used for pow_data_in * pow_data_in
    extra multipliers are used for any subsequent multiplication */
    localparam NUM_EXTRA_MULTS = POW - 2; 

    // total width of the multiplier cascade pipeline
    localparam POW_PIPE_WIDTH = LPM_PIPE_WIDTH * (POW - 1);

    /* precalculated indexes for grabbing the right input for subsequent
    multiplier cascades */
    localparam EXTRA_MULT_1_PIPE_IDX = (1 * LPM_PIPE_WIDTH) - 1;
    localparam EXTRA_MULT_2_PIPE_IDX = (2 * LPM_PIPE_WIDTH) - 1;
    localparam EXTRA_MULT_3_PIPE_IDX = (3 * LPM_PIPE_WIDTH) - 1;
    localparam EXTRA_MULT_4_PIPE_IDX = (4 * LPM_PIPE_WIDTH) - 1;
    localparam EXTRA_MULT_5_PIPE_IDX = (5 * LPM_PIPE_WIDTH) - 1;
    localparam EXTRA_MULT_6_PIPE_IDX = (6 * LPM_PIPE_WIDTH) - 1;
    localparam EXTRA_MULT_7_PIPE_IDX = (7 * LPM_PIPE_WIDTH) - 1;
    localparam EXTRA_MULT_8_PIPE_IDX = (8 * LPM_PIPE_WIDTH) - 1;

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    pow_ready_in;
    input logic [DATA_WIDTH-1:0]    pow_data_in;
    input logic                     pow_valid_in;

    // axi output interface
    input logic                     pow_ready_out;
    output logic [DATA_WIDTH-1:0]   pow_data_out;
    output logic                    pow_valid_out;

    // private signals
    logic [LPM_OUT_WIDTH-1:0]  mult_1_out;
    logic [LPM_OUT_WIDTH-1:0]  mult_n_out          [0:NUM_EXTRA_MULTS-1];
    logic [DATA_WIDTH-1:0]      pow_mult_n_data_in  [0:NUM_EXTRA_MULTS-1];

    logic [DATA_WIDTH-1:0] extra_mult_n_pipe_index [0:SUPPORTED_PRECISION-3];

    logic [POW_PIPE_WIDTH-1:0]  pow_valid_in_pipe;
    logic [DATA_WIDTH-1:0]      pow_data_in_pipe    [0:POW_PIPE_WIDTH-1];

    // instantiate power-of-2 multiplier (pow_data_in * pow_data_in)
    mult #(
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (LPM_PIPE_WIDTH)  
    ) multiplier_1 (
        .clken  (pow_ready_in),
        .clock  (clk),
        .dataa  (pow_data_in),
        .datab  (pow_data_in),
        .result (mult_1_out)
    );

    // pow_data_in pipeline
    generate 
        genvar pow_pipe;
        for (pow_pipe=0; pow_pipe<POW_PIPE_WIDTH; pow_pipe++) begin: POW_PIPE
            always_ff @(posedge clk) begin
                if (rst) begin
                    pow_data_in_pipe[pow_pipe] <= {DATA_WIDTH{1'b0}};
                end else begin
                    if (pow_ready_in) begin
                        // shift the input data along the pipe only when ready is high
                        pow_data_in_pipe <= {pow_data_in, pow_data_in_pipe[0:POW_PIPE_WIDTH-2]}; 
                    end
                end
            end
        end
    endgenerate

    // pow_valid_in pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            pow_valid_in_pipe <= {POW_PIPE_WIDTH{1'b0}};
        end else begin
            if (pow_ready_in) begin
                // shift the input valid along the pipe only when ready is high
                pow_valid_in_pipe <= {pow_valid_in_pipe[POW_PIPE_WIDTH-2:0],pow_valid_in}; 
            end
        end
    end

    // output valid is the last element in the pipe
    assign pow_valid_out = pow_valid_in_pipe[POW_PIPE_WIDTH-1]; 

    always_ff @(posedge clk) begin
        if (rst) begin
            extra_mult_n_pipe_index[0] <= EXTRA_MULT_1_PIPE_IDX;
            extra_mult_n_pipe_index[1] <= EXTRA_MULT_2_PIPE_IDX;
            extra_mult_n_pipe_index[2] <= EXTRA_MULT_3_PIPE_IDX;
            extra_mult_n_pipe_index[3] <= EXTRA_MULT_4_PIPE_IDX;
            extra_mult_n_pipe_index[4] <= EXTRA_MULT_5_PIPE_IDX;
            extra_mult_n_pipe_index[5] <= EXTRA_MULT_6_PIPE_IDX;
            extra_mult_n_pipe_index[6] <= EXTRA_MULT_7_PIPE_IDX;
            extra_mult_n_pipe_index[7] <= EXTRA_MULT_8_PIPE_IDX;
        end 
    end

    generate
        if (NUM_EXTRA_MULTS > 0) begin
            // POW > 2 necessitates extra multipliers
            genvar i;
            for (i=0; i<NUM_EXTRA_MULTS; i++) begin: POW

                /* instantiate extra multipliers
                if it's the first extra multiplier (i == 0), connect dataa to 
                the output of the power-of-2 multiplier, otherwise connect
                dataa to the output of the previous multiplier in the chain

                datab is connected to the pow_data_in_pipe, the index of the 
                pipe depends on the multiplier pipeline width and the multiplier 
                in the chain

                idx = ((i + 1) * single_multiplier_pipe_width) - 1

                since this involves a multiplication I chose to precalculate these
                and use a simple LUT, this is what limits the cascade length

                TODO: enforce pipe widths that are powers of 2 and use shift operators
                */
                mult #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .PIPE_WIDTH (LPM_PIPE_WIDTH)  
                ) multiplier_n (
                    .clken  (pow_ready_in),
                    .clock  (clk),
                    .dataa  ((i == 0) ? mult_1_out[LPM_OUT_MSB-:DATA_WIDTH] : mult_n_out[i-1][LPM_OUT_MSB-:DATA_WIDTH]),
                    .datab  (pow_data_in_pipe[extra_mult_n_pipe_index[i]]),
                    .result (mult_n_out[i])
                );
            end

            // output data is the last element in the pipe
            assign pow_data_out = mult_n_out[NUM_EXTRA_MULTS-1][LPM_OUT_MSB-:DATA_WIDTH];

        end else begin
            // otherwise just assign the data from the power-of-2 multiplier to the output
            assign pow_data_out = mult_1_out[LPM_OUT_MSB-:DATA_WIDTH];
        end
    endgenerate

    /* if in reset ready is low
    else allow data to flow in every combination other than valid is high and 
    ready is low */
    assign pow_ready_in = rst ? 1'b0 : ~pow_valid_out | pow_ready_out;

endmodule