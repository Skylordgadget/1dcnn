`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module pow_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam POW = 3; // pow_data_out = pow_data_in ** POW
    localparam DATA_WIDTH = 32;
    localparam LPM_PIPE_WIDTH = 4;
    localparam FRACTION = 24;

    logic clk;
    logic rst;

    logic                   pow_ready_in;
    logic [DATA_WIDTH-1:0]  pow_data_in;
    logic                   pow_valid_in;

    logic                   pow_ready_out;
    logic [DATA_WIDTH-1:0]  pow_data_out;
    logic                   pow_valid_out;

    int unsigned cycle_counter = 0;
    int unsigned pow_data_in_buf[pow.POW_PIPE_WIDTH];

    bit [DATA_WIDTH-1:0] rand_num;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    pow #(
        .POW            (POW),
        .DATA_WIDTH     (DATA_WIDTH),
        .LPM_PIPE_WIDTH (LPM_PIPE_WIDTH),
        .FRACTION       (FRACTION)
    ) pow (
        .clk    (clk),
        .rst    (rst),

        .pow_ready_in   (pow_ready_in),
        .pow_data_in    (pow_data_in),
        .pow_valid_in   (pow_valid_in),

        .pow_ready_out  (pow_ready_out),
        .pow_data_out   (pow_data_out),
        .pow_valid_out  (pow_valid_out)
    );


    initial begin
        pow_data_in = {DATA_WIDTH{1'b0}};
        pow_ready_out = 0;
        pow_valid_in = 0;
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;

        forever begin
            #(CLK_PERIOD);
            if (!rst) begin
                if (pow_ready_in) begin
                    pow_valid_in <= $urandom_range(1'b0, 1'b1);
                    rand_num = $urandom_range(0, 4);
                    pow_data_in <= rand_num;
                    pow_data_in_buf <= {pow_data_in, pow_data_in_buf[0:pow.POW_PIPE_WIDTH-2]};

                    if (cycle_counter == pow.POW_PIPE_WIDTH+1) begin
                        cycle_counter = 0;
                    end else begin
                        cycle_counter <= cycle_counter+1;
                    end
                end

                if (pow_valid_out) begin
                    if (!((pow_data_in_buf[pow.POW_PIPE_WIDTH-1]**3) == pow_data_out)) begin
                        $display("not poggers");
                        $stop;
                    end
                end
                pow_ready_out <= $urandom_range(1'b0, 1'b1);
            end 
        end
    end

    

endmodule