// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/mult.v"
`include "./../ip/sp_ram.v"
// synthesis translate_on


module conv1d (
    clk,
    rst,

    conv1d_ready_in,
    conv1d_valid_in,
    conv1d_data_in,

    conv1d_weights,
    conv1d_bias,

    conv1d_ready_out,
    conv1d_valid_out,
    conv1d_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter FILTER_SIZE = 5;
    parameter MAX_MULTS = 2;

    // total pipeline width
    
    localparam HAS_SUM_REDUCE = (FILTER_SIZE > 1) && (MAX_MULTS > 1);
    localparam MIN_SPLIT = ((FILTER_SIZE + MAX_MULTS - 1) / MAX_MULTS);
    localparam CONV1D_PIPE_WIDTH = LPM_PIPE_WIDTH + HAS_SUM_REDUCE + 1; // +1 because of data_buffer
    localparam KERNEL_MULT_CNT_WIDTH = clog2(MIN_SPLIT);
    localparam BUFFER_IDX_WIDTH = clog2(FILTER_SIZE);

    input logic                     clk;
    input logic                     rst;

    output logic                    conv1d_ready_in;
    input logic                     conv1d_valid_in;
    input logic [DATA_WIDTH-1:0]    conv1d_data_in;

    input logic [DATA_WIDTH-1:0]    conv1d_weights [0:FILTER_SIZE-1];
    input logic [DATA_WIDTH-1:0]    conv1d_bias;

    input logic                     conv1d_ready_out;
    output logic                    conv1d_valid_out;
    output logic [DATA_WIDTH-1:0]   conv1d_data_out;

    //`logic conv1d_ready_in;
    logic [DATA_WIDTH-1:0] data_buffer [0:FILTER_SIZE-1];
    logic [KERNEL_MULT_CNT_WIDTH-1:0] kernel_mult_cnt;
    logic [BUFFER_IDX_WIDTH-1:0] data_buffer_idx [0:MAX_MULTS-1];
    logic reset_kernel_mult_cnt;
    logic [LPM_OUT_WIDTH-1:0] mult_out [0:MAX_MULTS-1];
    logic [DATA_WIDTH-1:0] mult_in [0:MAX_MULTS-1];
    logic [DATA_WIDTH-1:0] weight_in [0:MAX_MULTS-1];
    logic [DATA_WIDTH-1:0] mult_sum [0:MAX_MULTS-1];
    logic [DATA_WIDTH-1:0] accumulator;
    logic [CONV1D_PIPE_WIDTH-1:0] conv1d_valid_in_pipe;
    logic [CONV1D_PIPE_WIDTH-1:0] reset_kernel_mult_cnt_pipe;
    logic valid_in;
    logic ready_in;

    logic [KERNEL_MULT_CNT_WIDTH-1:0] accum_cnt;
    logic reset_accum_cnt;

    // neuron_valid_in pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            conv1d_valid_in_pipe <= {CONV1D_PIPE_WIDTH{1'b0}};
        end else begin
            if (conv1d_ready_in) begin
                // shift the input valid along the pipe only when ready is high
                conv1d_valid_in_pipe <= {conv1d_valid_in_pipe[CONV1D_PIPE_WIDTH-2:0],conv1d_valid_in}; 
            end
        end
    end



    assign valid_in = conv1d_valid_in_pipe[0];
    assign conv1d_ready_in = ((~conv1d_valid_out | conv1d_ready_out) & conv1d_valid_in);

    generate
        genvar buf_idx;
        for (buf_idx=0; buf_idx < FILTER_SIZE; buf_idx++) begin
            always_ff @(posedge clk) begin
                if (rst) begin
                    data_buffer[buf_idx] <= {DATA_WIDTH{1'b0}};
                end else begin
                    // only register valid data when ready
                    if (conv1d_ready_in && reset_kernel_mult_cnt) begin
                        data_buffer <= {conv1d_data_in, data_buffer[0:FILTER_SIZE-1]};
                    end
                end
            end
        end
    endgenerate

    generate 
        if (MAX_MULTS < FILTER_SIZE) begin
            // reset_kernel_mult_cnt_pipe pipeline
            always_ff @(posedge clk) begin
                if (rst) begin
                    reset_kernel_mult_cnt_pipe <= {CONV1D_PIPE_WIDTH{1'b0}};
                end else begin
                    if (conv1d_ready_in) begin
                        // shift the input valid along the pipe only when ready is high
                        reset_kernel_mult_cnt_pipe <= {reset_kernel_mult_cnt_pipe[CONV1D_PIPE_WIDTH-2:0],reset_kernel_mult_cnt}; 
                    end
                end
            end

            always_ff @(posedge clk) begin
                if (rst) begin
                    kernel_mult_cnt <= {KERNEL_MULT_CNT_WIDTH{1'b0}};
                    reset_kernel_mult_cnt <= 1'b1;
                end else begin
                    reset_kernel_mult_cnt <= (kernel_mult_cnt == MIN_SPLIT-2);
                    if (ready_in) begin 
                        if (reset_kernel_mult_cnt) begin
                            kernel_mult_cnt <= {KERNEL_MULT_CNT_WIDTH{1'b0}};
                        end else begin
                            kernel_mult_cnt <= kernel_mult_cnt + 1'b1;
                        end
                    end
                end
            end
        end else begin
            assign reset_kernel_mult_cnt = 1'b1;
        end 
    endgenerate


    generate 
        genvar mult;
        for (mult=0; mult < MAX_MULTS; mult++) begin
            if (MAX_MULTS == FILTER_SIZE) begin

                assign data_buffer_idx[mult] = mult;

            end else if (MAX_MULTS == 1) begin

                assign data_buffer_idx[mult] = kernel_mult_cnt;

            end else begin

                always_ff @(posedge clk) begin
                    if (rst) begin
                        data_buffer_idx[mult] <= mult;
                    end else begin
                        if (ready_in) begin
                            if (reset_kernel_mult_cnt) begin
                                data_buffer_idx[mult] <= mult;
                            end else begin
                                data_buffer_idx[mult] <= data_buffer_idx[mult] + MAX_MULTS;
                            end
                        end
                    end
                end

            end

            assign mult_in[mult] = (data_buffer_idx[mult] > FILTER_SIZE-1) ? {DATA_WIDTH{1'b0}} : data_buffer[data_buffer_idx[mult]];
            assign weight_in[mult] = (data_buffer_idx[mult] > FILTER_SIZE-1) ? {DATA_WIDTH{1'b0}} : conv1d_weights[data_buffer_idx[mult]];

            mult #(
                .DATA_WIDTH (DATA_WIDTH),
                .PIPE_WIDTH (LPM_PIPE_WIDTH)  
            ) kernel_mult (
                .clken  (ready_in),
                .clock  (clk),
                .dataa  (mult_in[mult]),
                .datab  (weight_in[mult]),
                .result (mult_out[mult])
            );
        end
    endgenerate

    generate
        if (HAS_SUM_REDUCE) begin
            genvar j;
            for (j=1; j<MAX_MULTS; j++) begin: SUM_REDUCE
                always_ff @(posedge clk) begin
                    if (ready_in) begin
                        if (j==1) begin 
                            mult_sum[j] <= mult_out[j-1][LPM_OUT_MSB-:DATA_WIDTH] + mult_out[j][LPM_OUT_MSB-:DATA_WIDTH];
                        end else begin
                            mult_sum[j] <= mult_sum[j-1] + mult_out[j][LPM_OUT_MSB-:DATA_WIDTH];
                        end 
                    end
                end
            end
        end else begin
            assign mult_sum[MAX_MULTS-1] = mult_out[0][LPM_OUT_MSB-:DATA_WIDTH];
        end
    endgenerate

    generate 
        if ((FILTER_SIZE > 1) && (MAX_MULTS < FILTER_SIZE)) begin
            always_ff @(posedge clk) begin
                if (rst) begin
                    accumulator <= {DATA_WIDTH{1'b0}};
                end else begin
                    if (ready_in) begin
                        if (reset_kernel_mult_cnt_pipe[CONV1D_PIPE_WIDTH-1]) begin
                            accumulator <= mult_sum[MAX_MULTS-1];
                        end else begin
                            accumulator <= accumulator + mult_sum[MAX_MULTS-1];
                        end
                    end
                end
            end 


            always_ff @(posedge clk) begin
                if (rst) begin
                    accum_cnt <= {KERNEL_MULT_CNT_WIDTH{1'b0}};
                    reset_accum_cnt <= 1'b1;
                end else begin
                    reset_accum_cnt <= (accum_cnt == MIN_SPLIT-2);
                    conv1d_valid_out <= 1'b0;
                    if (ready_in && conv1d_valid_in_pipe[CONV1D_PIPE_WIDTH-1]) begin 
                        if (reset_accum_cnt) begin
                            accum_cnt <= {KERNEL_MULT_CNT_WIDTH{1'b0}};
                            conv1d_valid_out <= 1'b1;
                        end else begin
                            accum_cnt <= accum_cnt + 1'b1;
                        end
                    end
                end
            end

            assign conv1d_data_out = accumulator;
        end else begin

            assign conv1d_valid_out = conv1d_valid_in_pipe[CONV1D_PIPE_WIDTH-1];
            assign conv1d_data_out = mult_sum[MAX_MULTS-1];
        end

        
    endgenerate 

    assign ready_in = rst ? 1'b0 : (~conv1d_valid_out | conv1d_ready_out) & valid_in;


endmodule