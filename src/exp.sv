// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/div.v"
// synthesis translate_on

module exp (
    clk,
    rst,

    exp_ready_in,
    exp_valid_in,
    exp_data_in,

    debug_denom,

    exp_ready_out,
    exp_valid_out,
    exp_data_out
);
    import cnn1d_pkg::*;

    parameter PRECISION = 4;
    localparam NUM_DIVIDES = PRECISION - 2;

    input logic clk;
    input logic rst;

    output logic exp_ready_in;
    input logic exp_valid_in;
    input logic [DATA_WIDTH-1:0] exp_data_in;

    input logic [DATA_WIDTH-1:0] debug_denom;

    input logic exp_ready_out;
    output logic exp_valid_out;
    output logic [DATA_WIDTH-1:0] exp_data_out;

    logic [LPM_OUT_WIDTH-1:0] div_out;

    logic [DATA_WIDTH-1:0] factorial [0:SUPPORTED_PRECISION-1];


    logic [NUM_DIVIDES-1:0] pow_ready_in;
    logic [NUM_DIVIDES-1:0] pow_valid_out;
    logic [DATA_WIDTH-1:0] pow_data_out [0:NUM_DIVIDES-1];

    logic [DATA_WIDTH-1:0] div_data_out [0:NUM_DIVIDES-1];

    logic [DATA_WIDTH-1:0] div_sum [0:NUM_DIVIDES-1];

    // factorials LUT
    always_ff @(posedge clk) begin
        if (rst) begin
            factorial[0] <= FACTORIAL_1; // 1!
            factorial[1] <= FACTORIAL_2; // 2!
            factorial[2] <= FACTORIAL_3; // 3!
            factorial[3] <= FACTORIAL_4; // 4!
            factorial[4] <= FACTORIAL_5; // 5!
            factorial[5] <= FACTORIAL_6; // 6!
            factorial[6] <= FACTORIAL_7; // 7!
            factorial[7] <= FACTORIAL_8; // 8!
            factorial[8] <= FACTORIAL_9; // 9!
            factorial[9] <= FACTORIAL_10; // 10!
        end 
    end


    generate 
        if (NUM_DIVIDES > 0) begin
            genvar i;
            for (i=0; i<NUM_DIVIDES; i++) begin: DIV

                pow #(
                    .POW(i+2)
                ) power_of (
                    .clk    (clk),
                    .rst    (rst),

                    .pow_ready_in   (pow_ready_in[i]),
                    .pow_valid_in   (1'b1),
                    .pow_data_in    (exp_data_in),
                    
                    .pow_ready_out  (1'b1),
                    .pow_valid_out  (pow_valid_out[i]),
                    .pow_data_out   (pow_data_out[i])
                );

                div #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .PIPE_WIDTH (LPM_PIPE_WIDTH)
                ) divider (
                    .clken      (pow_valid_out[i]),
                    .clock      (clk),
                    .denom      (factorial[i+1]),
                    .numer      (pow_data_out[i]),
                    .quotient   (div_data_out[i]),
                    .remain     () // unconnected
                );
            end
        end

        if (NUM_DIVIDES > 1) begin
            genvar j;
            for (j=1; j<NUM_DIVIDES; j++) begin: SUM_REDUCE
                always_ff @(posedge clk) begin
                    if (j==1) begin 
                        div_sum[j] <= div_data_out[j-1] + div_data_out[j];
                    end else begin
                        div_sum[j] <= div_sum[j-1] + div_data_out[j];
                    end    
                end
            end
        end else if (NUM_DIVIDES > 0) begin
            assign div_sum[NUM_DIVIDES-1] = div_data_out[0];
        end else begin
            assign div_sum[NUM_DIVIDES-1] = {DATA_WIDTH{1'b0}};
        end
    endgenerate

    assign exp_data_out = {1'b1, {FRACTION{1'b0}}} + exp_data_in + div_sum[NUM_DIVIDES-1];


endmodule