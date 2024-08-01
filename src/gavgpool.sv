////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       gavgpool.sv                                               //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Basic global average pooling with AXI interface.          //
//                                                                            //
//                  Takes a sequential stream of data of length POOL_SIZE,    //
//                  sums it and divides it by POOL_SIZE.                      // 
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/div.v"
// synthesis translate_on

module gavgpool (
    clk,
    rst,

    gavgpool_ready_in,
    gavgpool_valid_in,
    gavgpool_data_in,

    gavgpool_ready_out,
    gavgpool_valid_out,
    gavgpool_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 12; // width of the incoming data
    parameter POOL_SIZE = 256;
    parameter PIPE_WIDTH = 4;

    localparam CLOG2_POOL_SIZE = clog2(POOL_SIZE);
    localparam COUNTER_WIDTH = CLOG2_POOL_SIZE;
    // ensure data is not lost when the whole pool is summed
    localparam ACCUMULATOR_WIDTH = DATA_WIDTH + COUNTER_WIDTH;
    localparam BIT_SEL = (ACCUMULATOR_WIDTH > 32) ? 32 : ACCUMULATOR_WIDTH;
    localparam PAD = (ACCUMULATOR_WIDTH > 32) ? ACCUMULATOR_WIDTH-32 : 0;   
    
    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    gavgpool_ready_in;
    input logic                     gavgpool_valid_in;
    input logic [DATA_WIDTH-1:0]    gavgpool_data_in;

    // axi output interface
    input logic                     gavgpool_ready_out;
    output logic                    gavgpool_valid_out;
    output logic [DATA_WIDTH-1:0]   gavgpool_data_out;

    // private signals
    logic                           accum_ready_out;
    logic                           accum_valid_out;
    logic [ACCUMULATOR_WIDTH-1:0]   accum_data_out, accum_data_out_shift;

    logic [PIPE_WIDTH-1:0]          div_valid_pipe;

    logic [ACCUMULATOR_WIDTH-1:0]   div_data_out;

    // accumulator
    accum #(
        .DATA_WIDTH         (DATA_WIDTH), 
        .POOL_SIZE          (POOL_SIZE)
    ) accumulator (
        .clk                (clk),
        .rst                (rst),

        .accum_ready_in     (gavgpool_ready_in),
        .accum_valid_in     (gavgpool_valid_in),
        .accum_data_in      (gavgpool_data_in),

        .accum_ready_out    (accum_ready_out),
        .accum_valid_out    (accum_valid_out),
        .accum_data_out     (accum_data_out)
    );

    

    // valid pipeline
    // always_ff @(posedge clk) begin
    //     if (rst) begin
    //         div_valid_pipe <= {PIPE_WIDTH{1'b0}};
    //     end else begin
    //         if (accum_ready_out) begin
    //             div_valid_pipe <= {div_valid_pipe[PIPE_WIDTH-2:0], accum_valid_out};
    //         end
    //     end
    // end

    //assign gavgpool_valid_out = div_valid_pipe[PIPE_WIDTH-1];


    // divider--TAKES TOO MANY LEs
    // div #(
    //     .DATA_WIDTH (ACCUMULATOR_WIDTH),
    //     .PIPE_WIDTH (PIPE_WIDTH)
    // ) divider (
    //     .clken      (accum_ready_out),
    //     .clock      (clk),
    //     .denom      ({{PAD{1'b0}},POOL_SIZE[BIT_SEL-1:0]}), 
    //     .numer      (accum_data_out),
    //     .quotient   (div_data_out),
    //     .remain     () // unconnected
    // );

    assign accum_ready_out = ~gavgpool_valid_out | gavgpool_ready_out;
    assign accum_data_out_shift = accum_data_out >> CLOG2_POOL_SIZE;
    always_ff @(posedge clk) begin
        if (rst) begin
            gavgpool_data_out <= {DATA_WIDTH{1'b0}};
            gavgpool_valid_out <= 1'b0;
        end else begin
            if (accum_valid_out && accum_ready_out) begin
                gavgpool_data_out <= accum_data_out_shift[DATA_WIDTH-1:0];
                gavgpool_valid_out <= 1'b1;
            end
            
            if (gavgpool_valid_out && gavgpool_ready_out) begin
                gavgpool_valid_out <= 1'b0;
            end 
        end
    end 


    // truncate data back down to the width of the input
    // assign gavgpool_data_out = div_data_out[DATA_WIDTH-1:0];


endmodule