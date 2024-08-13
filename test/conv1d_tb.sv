`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module conv1d_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam FILTER_SIZE = 5;
    localparam PIPE_WIDTH = 4;

    logic clk;
    logic rst;

    logic                   conv1d_ready_in;
    logic                   conv1d_valid_in;
    logic [DATA_WIDTH-1:0]  conv1d_data_in;

    logic [DATA_WIDTH-1:0]  conv1d_weights [0:FILTER_SIZE-1];
    logic [DATA_WIDTH-1:0]  conv1d_bias;

    logic                   conv1d_ready_out;
    logic                   conv1d_valid_out;
    logic [DATA_WIDTH-1:0]  conv1d_data_out;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    conv1d #(
        .DATA_WIDTH(DATA_WIDTH), 
        .FILTER_SIZE(FILTER_SIZE),
        .PIPE_WIDTH(PIPE_WIDTH)
    ) conv1d (
        .clk    (clk),
        .rst    (rst),

        .conv1d_ready_in   (conv1d_ready_in),
        .conv1d_valid_in   (conv1d_valid_in),
        .conv1d_data_in   (conv1d_data_in),

        .conv1d_weights (conv1d_weights),
        .conv1d_bias    (conv1d_bias),

        .conv1d_ready_out  (conv1d_ready_out),
        .conv1d_valid_out  (conv1d_valid_out),
        .conv1d_data_out  (conv1d_data_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic [DATA_WIDTH-1:0] rand_data;


    initial begin
        conv1d_ready_out = 1'b0;
        conv1d_valid_in = 1'b0;
        conv1d_data_in = {DATA_WIDTH{1'b0}};
        for (int i=0; i<FILTER_SIZE; i++) begin
            conv1d_weights[i] = $urandom_range(2, 10);
        end
        conv1d_bias = $urandom_range(2, 10);

        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        
        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            conv1d_ready_out <= 1'b1;
            //conv1d_ready_out <= $urandom_range(1'b0, 1'b1);
            if (conv1d_ready_in | ~conv1d_valid_in) begin
                rand_data = $urandom_range(0, 10);
                valid = 1'b1;
                //valid = $urandom_range(1'b0, 1'b1);
                conv1d_data_in <= rand_data;
                
                if (valid) begin
                    mbx.put(rand_data);
                end

                conv1d_valid_in <= valid;
            end
        end
        $display("Test completed successfully");
        $stop;
    end

    initial begin
        int mbx_received;
        int calculated;
        int kernel [FILTER_SIZE];
        for (int i=0; i<FILTER_SIZE; i++) begin
            kernel[i] = 0;
        end
        forever begin
            #(CLK_PERIOD);
            if (conv1d_valid_out && conv1d_ready_out) begin
                calculated = 0;
                
                mbx.get(mbx_received);
                kernel = {mbx_received, kernel[0:FILTER_SIZE-2]};
                for (int i=0; i<FILTER_SIZE; i++) begin
                    calculated = calculated + (kernel[i]*conv1d_weights[i]);
                end
                calculated = calculated + conv1d_bias;

                if (!(calculated == conv1d_data_out)) begin
                    $display("discrepency between calculated value: %d, and received value: %d", calculated, conv1d_data_out);
                    for(int i=0; i<FILTER_SIZE; i++) begin
                        $display("kernel[%d] = %d",i,kernel[i]);
                    end
                    $stop;
                end

            end
        end
    end


endmodule