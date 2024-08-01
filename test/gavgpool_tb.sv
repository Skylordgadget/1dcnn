`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module gavgpool_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam POOL_SIZE = 256;
    localparam PIPE_WIDTH = 4;
    localparam CLOG2_POOL_SIZE = clog2(POOL_SIZE);

    logic clk;
    logic rst;

    logic                   gavgpool_ready_in;
    logic                   gavgpool_valid_in;
    logic [DATA_WIDTH-1:0]  gavgpool_data_in;

    logic                   gavgpool_ready_out;
    logic                   gavgpool_valid_out;
    logic [DATA_WIDTH-1:0]  gavgpool_data_out;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    gavgpool #(
        .DATA_WIDTH     (DATA_WIDTH),
        .POOL_SIZE      (POOL_SIZE),
        .PIPE_WIDTH     (PIPE_WIDTH)
    ) gavgpool (
        .clk    (clk),
        .rst    (rst),

        .gavgpool_ready_in   (gavgpool_ready_in),
        .gavgpool_valid_in   (gavgpool_valid_in),
        .gavgpool_data_in    (gavgpool_data_in ), 

        .gavgpool_ready_out  (gavgpool_ready_out),
        .gavgpool_valid_out  (gavgpool_valid_out),
        .gavgpool_data_out   (gavgpool_data_out)
    );

    int unsigned num_inputs = 10000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic [DATA_WIDTH-1:0] rand_data;

    initial begin
        gavgpool_ready_out = 1'b0;
        gavgpool_valid_in = 1'b0;
        gavgpool_data_in = {DATA_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            //gavgpool_ready_out <= 1'b1;
            gavgpool_ready_out <= $urandom_range(1'b0, 1'b1);
            if (gavgpool_ready_in | ~gavgpool_valid_in) begin
                rand_data = $urandom_range(0, 10);
                //valid = 1'b1;
                valid = $urandom_range(1'b0, 1'b1);
                gavgpool_data_in <= rand_data;
                
                if (valid) begin
                    mbx.put(rand_data);
                end

                gavgpool_valid_in <= valid;
            end
        end
        $stop;
    end

    initial begin
        int mbx_received;
        int sum;
        forever begin
            #(CLK_PERIOD);
            if (gavgpool_valid_out && gavgpool_ready_out) begin
                sum = 0;
                for (int i=0; i<POOL_SIZE; i++) begin
                    mbx.get(mbx_received);
                    sum = sum + mbx_received;
                end
                if (!((sum >> CLOG2_POOL_SIZE) == gavgpool_data_out)) begin
                    $display("discrepency between calculated value: %d, and received value: %d (sum: %d)", (sum >> CLOG2_POOL_SIZE), gavgpool_data_out, sum);
                    $stop;
                end

            end
        end
    end


endmodule