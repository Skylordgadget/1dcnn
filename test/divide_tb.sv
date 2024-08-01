`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module divide_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam PIPE_WIDTH = 4;

    logic clk;
    logic rst;

    logic                   divide_ready_in;
    logic                   divide_valid_in;
    logic [DATA_WIDTH-1:0]  divide_numer_in;
    logic [DATA_WIDTH-1:0]  divide_denom_in;

    logic                   divide_ready_out;
    logic                   divide_valid_out;
    logic [DATA_WIDTH-1:0]  divide_quotient_out;
    logic [DATA_WIDTH-1:0]  divide_remain_out;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    divide #(
        .DATA_WIDTH     (DATA_WIDTH),
        .LPM_PIPE_WIDTH (PIPE_WIDTH)
    ) divide (
        .clk    (clk),
        .rst    (rst),

        .divide_ready_in   (divide_ready_in),
        .divide_valid_in   (divide_valid_in),
        .divide_numer_in   (divide_numer_in),
        .divide_denom_in   (divide_denom_in),

        .divide_ready_out  (divide_ready_out),
        .divide_valid_out  (divide_valid_out),
        .divide_quotient_out   (divide_quotient_out),
        .divide_remain_out  (divide_remain_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic [DATA_WIDTH-1:0] rand_numer;
    logic [DATA_WIDTH-1:0] rand_denom;

    initial begin
        divide_ready_out = 1'b0;
        divide_valid_in = 1'b0;
        divide_numer_in = {DATA_WIDTH{1'b0}};
        divide_denom_in = {DATA_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            divide_ready_out <= 1'b1;
            divide_ready_out <= $urandom_range(1'b0, 1'b1);
            if (divide_ready_in | ~divide_valid_in) begin
                rand_numer = $urandom_range(1, 10);
                rand_denom = $urandom_range(1, 10);
                valid = 1'b1;
                valid = $urandom_range(1'b0, 1'b1);
                divide_numer_in <= rand_numer;
                divide_denom_in <= rand_denom;
                if (valid) begin
                    mbx.put((rand_numer / rand_denom));
                end

                divide_valid_in <= valid;
            end
        end
        $display("test completed successfully");
        $stop;
    end

    initial begin
        int mbx_received;
        forever begin
            #(CLK_PERIOD);
            if (divide_valid_out && divide_ready_out) begin
                mbx.get(mbx_received);
                if (!(mbx_received == divide_quotient_out)) begin
                    $display("discrepency between calculated value: %d, and received value: %d", mbx_received, divide_quotient_out);
                    $stop;
                end

            end
        end
    end


endmodule