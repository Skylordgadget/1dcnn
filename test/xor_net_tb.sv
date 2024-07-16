`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module xor_net_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    
    logic clk;
    logic rst;

    logic [DATA_WIDTH-1:0] a;
    logic [DATA_WIDTH-1:0] b;

    logic [DATA_WIDTH-1:0] o;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    xor_net net(
        .clk    (clk),
        .rst    (rst),

        .a      (a),
        .b      (b),

        .o      (o)
    );

    initial begin
        a = 12'b000000000000;
        b = 12'b000000000000;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (20) @(posedge clk);
        a = 12'b001000000000;
        b = 12'b000000000000;
        repeat (20) @(posedge clk);
        a = 12'b000000000000;
        b = 12'b001000000000;
        repeat (20) @(posedge clk);
        a = 12'b001000000000;
        b = 12'b001000000000;
        repeat (100) @(posedge clk);
    end


endmodule