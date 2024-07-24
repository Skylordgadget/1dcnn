`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module p2s_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam NUM_ELEMENTS = 2;
    
    logic clk;
    logic rst;

    logic p2s_ready_in;
    logic p2s_valid_in;
    logic [DATA_WIDTH-1:0] p2s_parallel_in [0:NUM_ELEMENTS-1];

    logic p2s_ready_out;
    logic p2s_valid_out;
    logic [DATA_WIDTH-1:0] p2s_serial_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    p2s #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_ELEMENTS (NUM_ELEMENTS)
    ) p2s (
        .clk    (clk),
        .rst    (rst),

        .p2s_ready_in   (p2s_ready_in),
        .p2s_valid_in   (p2s_valid_in),
        .p2s_parallel_in    (p2s_parallel_in),

        .p2s_ready_out  (p2s_ready_out),
        .p2s_valid_out  (p2s_valid_out),
        .p2s_serial_out   (p2s_serial_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx = new(num_inputs*NUM_ELEMENTS);

    bit valid;
    logic [DATA_WIDTH-1:0] rand_data_p [0:NUM_ELEMENTS-1];
    logic [DATA_WIDTH-1:0] rand_data;

    initial begin
        p2s_ready_out = 1'b0;
        p2s_valid_in = 1'b0;
        for (int i=0; i<NUM_ELEMENTS; i++) begin
            p2s_parallel_in[i] = '0;
        end
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            //p2s_ready_out <= $urandom_range(1'b0, 1'b1);
            p2s_ready_out <= 1'b1;
            if (p2s_ready_in | ~p2s_valid_in) begin
                //valid = $urandom_range(1'b0, 1'b1);
                valid = 1'b1;
                for (int i=0; i<NUM_ELEMENTS; i++) begin
                    rand_data = $urandom_range(0, 10);
                    rand_data_p[i] = rand_data;
                    if (valid) begin
                        mbx.put(rand_data);
                    end
                end
                
                p2s_parallel_in <= rand_data_p;
                p2s_valid_in <= valid;
            end
        end
        $stop;
    end

    initial begin
        int mbx_received;
        int sum;
        forever begin
            #(CLK_PERIOD);
            if (p2s_valid_out && p2s_ready_out) begin
                mbx.get(mbx_received);
                if (!(mbx_received == p2s_serial_out)) begin
                    $display("discrepency between expected value: %d, and received value: %d", mbx_received, p2s_serial_out);
                    $stop;
                end
            end
        end
    end



endmodule