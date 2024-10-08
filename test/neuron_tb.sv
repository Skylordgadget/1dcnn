`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module neuron_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam NUM_INPUTS = 10;
    localparam PIPE_WIDTH = 4;
    localparam FRACTION   = 0;

    logic clk;
    logic rst;

    logic neuron_ready_in;
    logic neuron_valid_in;
    logic [DATA_WIDTH-1:0] neuron_data_in [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] neuron_weights [0:NUM_INPUTS-1];
    logic [DATA_WIDTH-1:0] neuron_bias;
    
    logic neuron_ready_out;
    logic neuron_valid_out;
    logic [DATA_WIDTH-1:0] neuron_data_out;

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    neuron #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_INPUTS (NUM_INPUTS),
        .PIPE_WIDTH (PIPE_WIDTH),
        .FRACTION   (FRACTION)
    ) neuron (
        .clk    (clk),
        .rst    (rst),

        .neuron_ready_in    (neuron_ready_in),
        .neuron_valid_in    (neuron_valid_in),
        .neuron_data_in     (neuron_data_in),

        .neuron_weights     (neuron_weights),
        .neuron_bias        (neuron_bias),

        .neuron_ready_out   (neuron_ready_out),
        .neuron_valid_out   (neuron_valid_out),
        .neuron_data_out    (neuron_data_out)
    );

    int unsigned num_inputs = 1000; 

    mailbox mbx = new(num_inputs);
    
    bit valid;
    logic [DATA_WIDTH-1:0] rand_num [0:NUM_INPUTS-1];
    

    initial begin
        static int sender_neuron_output = 0;
        neuron_ready_out = 1'b0;
        neuron_valid_in = 1'b0;
        for (int i=0; i<NUM_INPUTS; i++) begin
            neuron_data_in[i] = 0;
            neuron_weights[i] = $urandom_range(12'd0, 12'd4);
        end
        neuron_bias = $urandom_range(12'd0, 12'd4);
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        for (int i = 0; i < num_inputs; i++) begin
            #(CLK_PERIOD);
            
            neuron_ready_out <= 1'b1;
            //neuron_ready_out <= $urandom_range(1'b0, 1'b1);

            if (neuron_ready_in | ~neuron_valid_in) begin
                sender_neuron_output = 0;
                for (int j = 0; j < NUM_INPUTS; j++) begin
                    rand_num[j] = $urandom_range(12'd0, 12'd4);
                    sender_neuron_output = sender_neuron_output + (rand_num[j] * neuron_weights[j]);
                end
                sender_neuron_output = sender_neuron_output + neuron_bias;
                valid = 1'b1;
                //valid = $urandom_range(1'b0, 1'b1);
                neuron_data_in <= rand_num;
                if (valid) begin
                    mbx.put(sender_neuron_output);
                end
                neuron_valid_in <= valid;
            end
        end
        $display("Test completed successfully");
        $stop;
    end

    //int unsigned cnt;

    initial begin
        static int receiver_neuron_output = 0;
        forever begin
            #(CLK_PERIOD);
            if (neuron_valid_out && neuron_ready_out) begin
                
                mbx.get(receiver_neuron_output);
                
                if (receiver_neuron_output != neuron_data_out) begin
                    $display(" discrepency between received: %d, and calculated: %d", receiver_neuron_output, neuron_data_out);
                    $stop;
                end  
            end
            
        end
    end


endmodule