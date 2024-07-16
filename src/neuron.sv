// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
// synthesis translate_on

module neuron (
    clk,
    rst,

    neuron_ready_in,
    neuron_valid_in,
    neuron_data_in,

    neuron_weights,
    neuron_bias,

    neuron_ready_out,
    neuron_valid_out,
    neuron_data_out
);
    import cnn1d_pkg::*;

    parameter NUM_INPUTS = 1;

    localparam NEURON_PIPE_WIDTH = LPM_PIPE_WIDTH + NUM_INPUTS;

    input logic clk;
    input logic rst;

    output logic                    neuron_ready_in;
    input logic                     neuron_valid_in;

    input logic [DATA_WIDTH-1:0]    neuron_data_in      [0:NUM_INPUTS-1];
    input logic [DATA_WIDTH-1:0]    neuron_weights      [0:NUM_INPUTS-1];
    input logic [DATA_WIDTH-1:0]    neuron_bias;

    input logic                     neuron_ready_out;
    output logic                    neuron_valid_out;
    output logic [DATA_WIDTH-1:0]   neuron_data_out;

    logic [LPM_OUT_WIDTH-1:0] mult_out [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] mult_sum [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] z;

    logic [NEURON_PIPE_WIDTH-1:0]  neuron_valid_in_pipe;

    generate
        genvar i;
        for (i=0; i<NUM_INPUTS; i++) begin: MULT
            mult #( 
                .DATA_WIDTH (DATA_WIDTH),
                .PIPE_WIDTH (LPM_PIPE_WIDTH)
            ) multiplier (
                .clken  (neuron_ready_in),
                .clock  (clk),
                .dataa  (neuron_data_in[i]),
                .datab  (neuron_weights[i]),
                .result (mult_out[i])
            );
        end
    endgenerate

    // neuron_valid_in pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            neuron_valid_in_pipe <= {NEURON_PIPE_WIDTH{1'b0}};
        end else begin
            if (neuron_ready_in) begin
                // shift the input valid along the pipe only when ready is high
                neuron_valid_in_pipe <= {neuron_valid_in_pipe[NEURON_PIPE_WIDTH-2:0],neuron_valid_in}; 
            end
        end
    end

    assign neuron_valid_out = neuron_valid_in_pipe[NEURON_PIPE_WIDTH-1];

    generate
        if (NUM_INPUTS > 1) begin
            genvar j;
            for (j=1; j<NUM_INPUTS; j++) begin: SUM_REDUCE
                always_ff @(posedge clk) begin
                    if (neuron_ready_in) begin
                        if (j==1) begin 
                            mult_sum[j] <= mult_out[j-1][LPM_OUT_MSB-:DATA_WIDTH] + mult_out[j][LPM_OUT_MSB-:DATA_WIDTH];
                        end else begin
                            mult_sum[j] <= mult_sum[j-1] + mult_out[j][LPM_OUT_MSB-:DATA_WIDTH];
                        end 
                    end
                end
            end
        end else begin
            assign mult_sum[NUM_INPUTS-1] = mult_out[0][LPM_OUT_MSB-:DATA_WIDTH];
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            neuron_data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            neuron_data_out <= mult_sum[NUM_INPUTS-1] + neuron_bias;
        end
    end

    assign neuron_ready_in = rst ? 1'b0 : ~neuron_valid_out | neuron_ready_out;

endmodule