`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module xor_net_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam NUM_INPUTS = 2;

    logic clk;
    logic rst;

    logic [NUM_INPUTS-1:0]  xor_net_ready_in;
    logic [NUM_INPUTS-1:0]  xor_net_valid_in;
    logic [DATA_WIDTH-1:0]  xor_net_data_in     [0:NUM_INPUTS-1];

    logic                   xor_net_ready_out;
    logic                   xor_net_valid_out;
    logic [DATA_WIDTH-1:0]  xor_net_data_out;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    xor_net net(
        .clk    (clk),
        .rst    (rst),

        .xor_net_ready_in   (xor_net_ready_in),
        .xor_net_valid_in   (xor_net_valid_in),
        .xor_net_data_in    (xor_net_data_in ), 

        .xor_net_ready_out  (xor_net_ready_out),
        .xor_net_valid_out  (xor_net_valid_out),
        .xor_net_data_out   (xor_net_data_out)
    );

    initial begin
        for (int i=0; i<NUM_INPUTS; i++) begin
            xor_net_data_in[i] = {DATA_WIDTH{1'b0}};
            xor_net_valid_in[i] = 1'b0;
        end
        xor_net_ready_out = 1'b0;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        #(CLK_PERIOD)
        xor_net_ready_out = 1'b1;
        for (int i=0; i<NUM_INPUTS; i++) begin
            xor_net_valid_in[i] = 1'b1;
        end
        #(CLK_PERIOD)
        xor_net_data_in[0] = 12'b001000000000;
        xor_net_data_in[1] = 12'b000000000000;
        #(CLK_PERIOD)
        xor_net_data_in[0] = 12'b000000000000;
        xor_net_data_in[1] = 12'b001000000000;
        #(CLK_PERIOD)
        xor_net_data_in[0] = 12'b001000000000;
        xor_net_data_in[1] = 12'b001000000000;
        forever #1;
    end


endmodule