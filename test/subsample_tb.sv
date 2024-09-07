`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module subsample_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam SUBSAMPLE_FACTOR = 400;

    localparam COUNTER_WIDTH = clog2(SUBSAMPLE_FACTOR);

    logic clk;
    logic rst;

    logic                   subsample_ready_in;
    logic                   subsample_valid_in;
    logic [DATA_WIDTH-1:0]  subsample_data_in;

    logic                   subsample_ready_out;
    logic                   subsample_valid_out;
    logic [DATA_WIDTH-1:0]  subsample_data_out; 

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    subsample #(
        .DATA_WIDTH         (DATA_WIDTH), 
        .SUBSAMPLE_FACTOR   (SUBSAMPLE_FACTOR)
    ) subsample (
        .clk    (clk),
        .rst    (rst),

        .subsample_ready_in  (subsample_ready_in),
        .subsample_valid_in  (subsample_valid_in),
        .subsample_data_in   (subsample_data_in),

        .subsample_ready_out (subsample_ready_out),
        .subsample_valid_out (subsample_valid_out),
        .subsample_data_out  (subsample_data_out)
    );

    int unsigned num_inputs = 1000000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic [DATA_WIDTH-1:0] rand_data;

    initial begin
        int count = 0;
        subsample_ready_out = 1'b0;
        subsample_valid_in = 1'b0;
        subsample_data_in = {DATA_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            //subsample_ready_out <= 1'b1;
            subsample_ready_out <= $urandom_range(1'b0, 1'b1);
            if (subsample_ready_in | ~subsample_valid_in) begin
                rand_data = $urandom_range(0, 10);
                //valid = 1'b1;
                valid = $urandom_range(1'b0, 1'b1);
                subsample_data_in <= rand_data;
                
                if (valid) begin
                    if (count < SUBSAMPLE_FACTOR-1) begin
                        count++;
                    end else begin
                        count = 0;
                        mbx.put(rand_data);
                    end
                end

                subsample_valid_in <= valid;
            end
        end
        $stop;
    end

    initial begin
        int mbx_received;
        forever begin
            #(CLK_PERIOD);
            if (subsample_valid_out && subsample_ready_out) begin
                mbx.get(mbx_received);
                if (!(mbx_received == subsample_data_out)) begin
                    $display("discrepency between expected value: %d, and received value: %d", mbx_received, subsample_data_out);
                    $stop;
                end
            end
        end
    end


endmodule