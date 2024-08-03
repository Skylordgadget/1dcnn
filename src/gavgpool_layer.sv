////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       gavgpool_layer.sv                                         //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Parallel global average pools with an AXI interface.      //
//                                                                            //
//                  Instantiates NUM_POOLS parallel global average pools.     //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

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

    parameter DATA_WIDTH    = 12; // width of the incoming data
    parameter POOL_SIZE     = 250;
    parameter NUM_POOLS     = 32;
    parameter PIPE_WIDTH    = 4;

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    gavgpool_layer_ready_in;
    input logic [NUM_POOLS-1:0]     gavgpool_layer_valid_in;
    input logic [DATA_WIDTH-1:0]    gavgpool_layer_data_in  [0:NUM_POOLS-1];

    // axi output interface
    input logic                     gavgpool_layer_ready_out;
    output logic [NUM_POOLS-1:0]    gavgpool_layer_valid_out;
    output logic [DATA_WIDTH-1:0]   gavgpool_layer_data_out [0:NUM_POOLS-1];

    // private signals
    logic [NUM_POOLS-1:0] gavg_pool_ready_in;
    
    // if all the pools are ready then the global average pool layer is ready
    assign gavgpool_layer_ready_in = &gavg_pool_ready_in;

    generate
        genvar pool;

        // global average pools
        for (pool=0; pool<NUM_POOLS; pool++) begin: GLOBAL_AVERAGE_POOLING
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


