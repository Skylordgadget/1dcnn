`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module conv1d_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam FILTER_SIZE = 5;
    localparam MAX_MULTS = 5;

    logic clk;
    logic rst;

    logic                   conv1d_ready_in;
    logic                   conv1d_valid_in;
    logic [DATA_WIDTH-1:0]  conv1d_data_in;

    logic [DATA_WIDTH-1:0]  conv1d_weights [0:FILTER_SIZE-1];
    logic [DATA_WIDTH-1:0]  conv1d_bias;

    logic                   conv1d_ready_out;
    logic                   conv1d_valid_out;
    logic [DATA_WIDTH-1:0]  conv1d_data_out;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    conv1d #(
        .DATA_WIDTH(DATA_WIDTH), 
        .FILTER_SIZE(FILTER_SIZE),
        .MAX_MULTS(MAX_MULTS)
    ) conv1d (
        .clk    (clk),
        .rst    (rst),

        .conv1d_ready_in   (conv1d_ready_in),
        .conv1d_valid_in   (conv1d_valid_in),
        .conv1d_data_in   (conv1d_data_in),

        .conv1d_weights (conv1d_weights),
        .conv1d_bias    (conv1d_bias),

        .conv1d_ready_out  (conv1d_ready_out),
        .conv1d_valid_out  (conv1d_valid_out),
        .conv1d_data_out  (conv1d_data_out)
    );

    initial begin
        conv1d_ready_out = 1'b0;
        conv1d_valid_in = 1'b0;
        conv1d_data_in = 12'd1;
        for (int i=0; i<FILTER_SIZE; i++) begin
            conv1d_weights[i] = 12'd0;
        end
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        conv1d_valid_in = 1'b1;
        conv1d_ready_out = 1'b1;
        conv1d_data_in = 12'd1;
        for (int i=0; i<FILTER_SIZE; i++) begin
            conv1d_weights[i] = 12'd1;
        end
        forever #1;
    end


endmodule