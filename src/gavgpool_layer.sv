module gavgpool_layer (
    clk,
    rst,

    gavgpool_layer_ready_in,
    gavgpool_layer_valid_in,
    gavgpool_layer_data_in,

    gavgpool_layer_ready_out,
    gavgpool_layer_valid_out,
    gavgpool_layer_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 12; // width of the incoming data
    parameter POOL_SIZE = 250;
    parameter NUM_POOLS = 32;
    parameter PIPE_WIDTH = 4;

    input logic clk;
    input logic rst;

    output logic gavgpool_layer_ready_in;
    input logic [NUM_POOLS-1:0] gavgpool_layer_valid_in;
    input logic [DATA_WIDTH-1:0] gavgpool_layer_data_in [0:NUM_POOLS-1];

    input logic gavgpool_layer_ready_out;
    output logic [NUM_POOLS-1:0] gavgpool_layer_valid_out;
    output logic [DATA_WIDTH-1:0] gavgpool_layer_data_out [0:NUM_POOLS-1];

    logic [NUM_POOLS-1:0] gavg_pool_ready_in;
    assign gavgpool_layer_ready_in = &gavg_pool_ready_in;

    generate
        genvar pool;

        for (pool=0; pool<NUM_POOLS; pool++) begin
            gavgpool #(
                .DATA_WIDTH     (DATA_WIDTH),
                .POOL_SIZE      (POOL_SIZE),
                .PIPE_WIDTH     (PIPE_WIDTH)
            ) gavgpool (
                .clk    (clk),
                .rst    (rst),

                .gavgpool_ready_in   (gavg_pool_ready_in[pool]),
                .gavgpool_valid_in   (gavgpool_layer_valid_in[pool]),
                .gavgpool_data_in    (gavgpool_layer_data_in[pool]), 

                .gavgpool_ready_out  (gavgpool_layer_ready_out),
                .gavgpool_valid_out  (gavgpool_layer_valid_out[pool]),
                .gavgpool_data_out   (gavgpool_layer_data_out[pool])
            );
        end

    endgenerate   
 
endmodule


