`timescale 1ns / 1ns

module accum_single_sample_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 12;
    localparam POOL_SIZE = 10;

    localparam COUNTER_WIDTH = clog2(POOL_SIZE);
    localparam ACCUMULATOR_WIDTH = DATA_WIDTH + COUNTER_WIDTH;

    logic clk;
    logic rst;

    logic                   accum_ready_in;
    logic                   accum_valid_in;
    logic [DATA_WIDTH-1:0]  accum_data_in;

    logic                   accum_ready_out;
    logic                   accum_valid_out;
    logic [ACCUMULATOR_WIDTH-1:0]  accum_data_out; 

    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    accum_single_sample #(
        .DATA_WIDTH(DATA_WIDTH), 
        .POOL_SIZE(POOL_SIZE)
    ) accum (
        .clk    (clk),
        .rst    (rst),

        .accum_ready_in (accum_ready_in),
        .accum_valid_in (accum_valid_in),
        .accum_data_in (accum_data_in),

        .accum_ready_out (accum_ready_out),
        .accum_valid_out (accum_valid_out),
        .accum_data_out  (accum_data_out)
    );

    int unsigned num_inputs = 1000;

    mailbox mbx = new(num_inputs);

    bit valid;
    logic [DATA_WIDTH-1:0] rand_data;
    int unsigned tb_accum_reg [POOL_SIZE];
    int unsigned tb_accum;

    initial begin
        accum_ready_out = 1'b0;
        accum_valid_in = 1'b0;
        accum_data_in = {DATA_WIDTH{1'b0}};
        tb_accum = 'b0;
        for (int i=0; i<POOL_SIZE; i++) begin
            tb_accum_reg[i] = 'b0;
        end
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        for (int i=0; i<num_inputs; i++) begin
            #(CLK_PERIOD);

            accum_ready_out <= 1'b1;
            //accum_ready_out <= $urandom_range(1'b0, 1'b1);
            if (accum_ready_in | ~accum_valid_in) begin
                rand_data = $urandom_range(0, 10);
                valid = 1'b1;
                //valid = $urandom_range(1'b0, 1'b1);
                accum_data_in <= rand_data;
                
                if (valid) begin
                    for (int j=POOL_SIZE-1; j>0; j--) begin
                        tb_accum_reg[j] = tb_accum_reg[j-1];
                    end
                    tb_accum_reg[0] = rand_data;
                    tb_accum = (tb_accum + tb_accum_reg[0]) - tb_accum_reg[POOL_SIZE-1];
                    mbx.put(tb_accum);
                end

                accum_valid_in <= valid;
            end
        end
        $stop;
    end

    initial begin
        int mbx_received;
        forever begin
            #(CLK_PERIOD);
            if (accum_valid_out && accum_ready_out) begin
                mbx.get(mbx_received);
                if (!(mbx_received == accum_data_out)) begin
                    $display("discrepency between calculated value: %d, and received value: %d", mbx_received, accum_data_out);
                    $stop;
                end

            end
        end
    end


endmodule