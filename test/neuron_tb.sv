`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module neuron_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    
    logic clk;
    logic rst;
    logic [DATA_WIDTH-1:0] a [1];
    logic [DATA_WIDTH-1:0] w [1];
    logic [DATA_WIDTH-1:0] bias;
    logic [DATA_WIDTH-1:0] o;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    neuron neuron(
        .clk    (clk),
        .rst    (rst),

        .a  (a),
        .w (w),
        .bias   (bias),

        .o (o)
    );

    initial begin
        a[0] = 0;
        w[0] = 0;
        bias = 0;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        #20;
        a[0] = -5;
        w[0] = 5;
        bias = 5;
        #4;
        #100;
    end


endmodule