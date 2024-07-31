`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module exp_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam PRECISION = 4;
    localparam LPM_PIPE_WIDTH = 4;
    localparam FRACTION = 9;

    logic clk;
    logic rst;

    logic exp_ready_in;
    logic exp_valid_in;
    logic [DATA_WIDTH-1:0] exp_data_in;

    logic exp_ready_out;
    logic exp_valid_out;
    logic [DATA_WIDTH-1:0] exp_data_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    exp #(
        .DATA_WIDTH     (DATA_WIDTH),
        .PRECISION      (PRECISION),
        .LPM_PIPE_WIDTH (LPM_PIPE_WIDTH),
        .FRACTION       (FRACTION)
    ) exp (
        .clk    (clk),
        .rst    (rst),

        .exp_ready_in   (exp_ready_in),
        .exp_valid_in   (exp_valid_in),
        .exp_data_in    (exp_data_in),

        .exp_ready_out  (exp_ready_out),
        .exp_valid_out  (exp_valid_out),
        .exp_data_out   (exp_data_out)
    );

    initial begin
        exp_data_in = {DATA_WIDTH{1'b0}};
        exp_ready_out = 1'b0;
        exp_valid_in = 1'b0;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        exp_ready_out = 1'b1;
        exp_valid_in = 1'b1;
        exp_data_in = 12'b001000000000;
        while (!exp_ready_in) begin
            #(CLK_PERIOD);
        end
        exp_data_in = 12'b000001000000;
        while (!exp_ready_in) begin
            #(CLK_PERIOD);
        end
        exp_data_in = 12'b000000100000;
        while (!exp_ready_in) begin
            #(CLK_PERIOD);
        end
        exp_data_in = 12'b100101000000;
        while (!exp_ready_in) begin
            #(CLK_PERIOD);
        end
        exp_data_in = 12'b000001000100;
        #(CLK_PERIOD);
    end


endmodule