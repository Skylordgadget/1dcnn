// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult_accum.v"
// synthesis translate_on

module mult_reduce (
    clk,
    rst,

    mult_reduce_ready_in,
    mult_reduce_valid_in,
    mult_reduce_dataa_in,
    mult_reduce_datab_in,

    mult_reduce_ready_out,
    mult_reduce_valid_out,
    mult_reduce_result_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter NUM_ELEMENTS = 5;
    parameter PIPE_WIDTH = 2;

    localparam MULT_OUT_WIDTH = (DATA_WIDTH * 2) + 1;
    localparam ELEMENT_COUNTER_WIDTH = clog2(NUM_ELEMENTS);
    localparam MULT_REDUCE_PIPE_LENGTH = PIPE_WIDTH + 3; // extra registers in the altmult_accum module 

    input logic clk;
    input logic rst;

    output  logic                       mult_reduce_ready_in;
    input   logic                       mult_reduce_valid_in;
    input   logic [DATA_WIDTH-1:0]      mult_reduce_dataa_in;
    input   logic [DATA_WIDTH-1:0]      mult_reduce_datab_in;

    input   logic                       mult_reduce_ready_out;
    output  logic                       mult_reduce_valid_out;
    output  logic [MULT_OUT_WIDTH-1:0]  mult_reduce_result_out; 

    logic clear_accum;

    logic [ELEMENT_COUNTER_WIDTH-1:0] element_counter; 
    logic reset_element_counter;
    logic [MULT_REDUCE_PIPE_LENGTH-1:0] mult_reduce_valid_in_pipe;
    logic reset_element_counter_pipe;

    always_ff @(posedge clk) begin
        if (rst) begin
            mult_reduce_valid_in_pipe <= 1'b0;
            reset_element_counter_pipe <= 1'b0;
        end else begin
            if (mult_reduce_ready_in) begin
                mult_reduce_valid_in_pipe <= {mult_reduce_valid_in_pipe[MULT_REDUCE_PIPE_LENGTH-2:0], mult_reduce_valid_in};
                reset_element_counter_pipe <= reset_element_counter;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            element_counter <= {ELEMENT_COUNTER_WIDTH{1'b0}};
            reset_element_counter <= 1'b0;
        end else begin
            if (mult_reduce_ready_in) begin
                reset_element_counter <= (element_counter == NUM_ELEMENTS-2);
                if (reset_element_counter) begin
                    element_counter <= {ELEMENT_COUNTER_WIDTH{1'b0}};
                    reset_element_counter <= 1'b0;
                end else begin
                    element_counter <= element_counter + 1'b1;
                end
            end
        end
    end 

    assign clear_accum = reset_element_counter_pipe;

    mult_accum #(
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (PIPE_WIDTH)
    ) multiply_accumulate (
        .accum_sload(clear_accum),
        .clock0     (clk),
        .dataa      (mult_reduce_dataa_in),
        .datab      (mult_reduce_datab_in),
        .ena0       (mult_reduce_ready_in),
        .result     (mult_reduce_result_out)
    );


    always_ff @(posedge clk) begin
        if (rst) begin
            mult_reduce_valid_out <= 1'b0;
        end else begin
            if (mult_reduce_ready_in) begin
                mult_reduce_valid_out <= clear_accum & mult_reduce_valid_in_pipe[MULT_REDUCE_PIPE_LENGTH-2];
            end 
        end
    end

    assign mult_reduce_ready_in = rst ? 1'b0 : ~mult_reduce_valid_out | mult_reduce_ready_out;

endmodule
