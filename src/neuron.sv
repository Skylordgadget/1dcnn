// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
// synthesis translate_on

module neuron (
    clk,
    rst,

    a,
    w,
    bias,

    o
);
    import cnn1d_pkg::*;

    parameter NUM_INPUTS = 1;

    input logic clk;
    input logic rst;

    input logic [DATA_WIDTH-1:0]    a       [0:NUM_INPUTS-1];
    input logic [DATA_WIDTH-1:0]    w       [0:NUM_INPUTS-1];
    input logic [DATA_WIDTH-1:0]    bias;

    output logic [DATA_WIDTH-1:0]  o;

    logic [LPM_OUT_WIDTH-1:0] mult_out [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] mult_sum [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] z;

    generate
        genvar i;
        for (i=0; i<NUM_INPUTS; i++) begin: MULT
            mult #( 
                .DATA_WIDTH (DATA_WIDTH),
                .PIPE_WIDTH (LPM_PIPE_WIDTH)
            ) multiplier (
                .clken  (1'b1),
                .clock  (clk),
                .dataa  (a[i]),
                .datab  (w[i]),
                .result (mult_out[i])
            );
        end
    endgenerate

    generate
        if (NUM_INPUTS > 1) begin
            genvar j;
            for (j=1; j<NUM_INPUTS; j++) begin: SUM_REDUCE
                always_ff @(posedge clk) begin
                    if (j==1) begin 
                        mult_sum[j] <= mult_out[j-1][LPM_OUT_MSB-:DATA_WIDTH] + mult_out[j][LPM_OUT_MSB-:DATA_WIDTH];
                    end else begin
                        mult_sum[j] <= mult_sum[j-1] + mult_out[j][LPM_OUT_MSB-:DATA_WIDTH];
                    end    
                end
            end
        end else begin
            assign mult_sum = mult_out[0][LPM_OUT_MSB-:DATA_WIDTH];
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            z <= {DATA_WIDTH{1'b0}};
        end else begin
            z <= mult_sum + bias;
        end
    end

    relu activation (
        .clk    (clk),
        .rst    (rst),
        
        .a      (z),
        .o      (o)
    );


endmodule