`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module mult_reduce_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam NUM_ELEMENTS = 5;
    localparam PIPE_WIDTH = 4;
    localparam MULT_OUT_WIDTH = (DATA_WIDTH * 2) + 1;

    logic clk;
    logic rst;

    logic                   mult_reduce_ready_in;
    logic                   mult_reduce_valid_in;
    logic [DATA_WIDTH-1:0]  mult_reduce_dataa_in;
    logic [DATA_WIDTH-1:0]  mult_reduce_datab_in;

    logic                   mult_reduce_ready_out;
    logic                   mult_reduce_valid_out;
    logic [MULT_OUT_WIDTH-1:0]  mult_reduce_result_out; 

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    mult_reduce #(
        .DATA_WIDTH(DATA_WIDTH), 
        .NUM_ELEMENTS(NUM_ELEMENTS),
        .PIPE_WIDTH(PIPE_WIDTH)
    ) mult_reduce (
        .clk    (clk),
        .rst    (rst),

        .mult_reduce_ready_in (mult_reduce_ready_in),
        .mult_reduce_valid_in (mult_reduce_valid_in),
        .mult_reduce_dataa_in (mult_reduce_dataa_in),
        .mult_reduce_datab_in (mult_reduce_datab_in),

        .mult_reduce_ready_out (mult_reduce_ready_out),
        .mult_reduce_valid_out (mult_reduce_valid_out),
        .mult_reduce_result_out (mult_reduce_result_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic [DATA_WIDTH-1:0] rand_dataa;
    logic [DATA_WIDTH-1:0] rand_datab;

    initial begin
        mult_reduce_ready_out = 1'b0;
        mult_reduce_valid_in = 1'b0;
        mult_reduce_dataa_in = 12'd1;
        mult_reduce_datab_in = 12'd2;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            mult_reduce_ready_out <= 1'b1;
            if (mult_reduce_ready_in | ~mult_reduce_valid_in) begin
                rand_dataa = $urandom_range(0, 10);
                rand_datab = $urandom_range(0, 10);
                valid = 1'b1;
                mult_reduce_dataa_in <= rand_dataa;
                mult_reduce_datab_in <= rand_datab;
                
                if (valid) begin
                    mbx.put(rand_dataa * rand_datab);
                end

                mult_reduce_valid_in <= valid;
            end
        end
        $stop;
    end

    initial begin
        int mbx_received;
        int sum;
        forever begin
            #(CLK_PERIOD);
            if (mult_reduce_valid_out && mult_reduce_ready_out) begin
                sum = 0;
                for (int i=0; i<NUM_ELEMENTS; i++) begin
                    mbx.get(mbx_received);
                    sum = sum + mbx_received;
                end
                if (!(sum == mult_reduce_result_out)) begin
                    $display("discrepency between calculated value: %d, and received value: %d", sum, mult_reduce_result_out);
                    $stop;
                end

            end
        end
    end


endmodule