`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module exp_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    
    logic clk;
    logic rst;

    logic exp_ready_in;
    logic exp_valid_in;
    logic [DATA_WIDTH-1:0] exp_data_in;

    logic [DATA_WIDTH-1:0] debug_denom;

    logic exp_ready_out;
    logic exp_valid_out;
    logic [DATA_WIDTH-1:0] exp_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    exp #(
        .PRECISION (6)
    ) exp (
        .clk    (clk),
        .rst    (rst),

        .exp_ready_in   (exp_ready_in),
        .exp_valid_in   (exp_valid_in),
        .exp_data_in    (exp_data_in),

        .debug_denom    (debug_denom),

        .exp_ready_out  (exp_ready_out),
        .exp_valid_out  (exp_valid_out),
        .exp_data_out   (exp_data_out)
    );

    initial begin
        exp_data_in = 12'b000000000000;
        debug_denom = 12'd3;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (100) @(posedge clk);
        exp_data_in = 12'b000001000000;
        repeat (100) @(posedge clk);
        exp_data_in = 12'b000000100000;
        repeat (100) @(posedge clk);
        exp_data_in = 12'b100101000000;
        repeat (100) @(posedge clk);
        exp_data_in = 12'b000001000100;
        repeat (100) @(posedge clk);
    end


endmodule