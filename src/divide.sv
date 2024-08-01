module divide (
    rst,
    clk,

    divide_ready_in,
    divide_valid_in,
    divide_numer_in,
    divide_denom_in,

    divide_ready_out,
    divide_valid_out,
    divide_quotient_out,
    divide_remain_out
);

    parameter DATA_WIDTH = 32;
    parameter LPM_PIPE_WIDTH = 4;

    input logic                     clk;
    input logic                     rst;

    output logic                    divide_ready_in;
    input logic                     divide_valid_in;
    input logic [DATA_WIDTH-1:0]    divide_numer_in;
    input logic [DATA_WIDTH-1:0]    divide_denom_in;

    input logic                     divide_ready_out;
    output logic                    divide_valid_out;
    output logic [DATA_WIDTH-1:0]   divide_quotient_out; 
    output logic [DATA_WIDTH-1:0]   divide_remain_out;
    
    logic [LPM_PIPE_WIDTH-1:0] valid_pipe;   

    assign divide_ready_in = ~divide_valid_out | divide_ready_out;

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_pipe <= {LPM_PIPE_WIDTH{1'b0}};
        end else begin
            if (divide_ready_in) begin
                valid_pipe <= {valid_pipe[LPM_PIPE_WIDTH-2:0], divide_valid_in};
            end
        end
    end

    div #(
        .DATA_WIDTH (DATA_WIDTH),
        .PIPE_WIDTH (LPM_PIPE_WIDTH)
    ) divider (
        .clken      (divide_ready_in),
        .clock      (clk),
        .denom      (divide_denom_in),
        .numer      (divide_numer_in),
        .quotient   (divide_quotient_out),
        .remain     (divide_remain_out)
    );   

    assign divide_valid_out = valid_pipe[LPM_PIPE_WIDTH-1];    

endmodule 