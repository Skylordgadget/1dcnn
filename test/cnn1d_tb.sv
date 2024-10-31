`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"

module cnn1d_tb();
    import cnn1d_pkg::*;
    
    localparam CLK_PERIOD = 10;
    localparam DATA_WIDTH = 32;
    localparam CONV_WEIGHTS_INIT_FILE = "../weights/two_filters_conv1d_weights_8I24F.hex";
    localparam CONV_BIASES_INIT_FILE = "../weights/two_filters_conv1d_biases_8I24F.hex";
    localparam NUM_FILTERS = 2;
    localparam FILTER_SIZE = 5;
    localparam PIPE_WIDTH = 4;
    localparam FRACTION = 24; // position of the decimal point from the right 
    localparam POOL_SIZE = 256;
    localparam NEURON_WEIGHTS_INIT_FILE = "../weights/two_filters_fc_weights_8I24F.hex";
    localparam NEURON_BIASES_INIT_FILE = "../weights/two_filters_fc_biases_8I24F.hex";
    localparam NUM_NEURONS = 2;
    localparam SUBSAMPLE_FACTOR = 1;
    localparam ADC_REF = 2500;
    localparam SCALE_FACTOR = 32'h000aaaab;
    localparam BIAS = 32'hfffffb1e;



    logic clk;
    logic rst;

    logic cnn_ready_in;
    logic cnn_valid_in;
    logic [DATA_WIDTH-1:0] cnn_data_in;

    logic cnn_ready_out;

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    m08_cnn1d #(
        .DATA_WIDTH (DATA_WIDTH),
        .CONV_WEIGHTS_INIT_FILE (CONV_WEIGHTS_INIT_FILE),
        .CONV_BIASES_INIT_FILE (CONV_BIASES_INIT_FILE),
        .NUM_FILTERS (NUM_FILTERS),
        .FILTER_SIZE (FILTER_SIZE),
        .PIPE_WIDTH (PIPE_WIDTH),
        .FRACTION (FRACTION),
        .POOL_SIZE (POOL_SIZE),
        .NEURON_WEIGHTS_INIT_FILE (NEURON_WEIGHTS_INIT_FILE),
        .NEURON_BIASES_INIT_FILE (NEURON_BIASES_INIT_FILE),
        .NUM_NEURONS (NUM_NEURONS),
        .SUBSAMPLE_FACTOR (SUBSAMPLE_FACTOR),
        .ADC_REF (ADC_REF),
        .SCALE_FACTOR (SCALE_FACTOR),
        .BIAS (BIAS)
    ) m08_cnn1d (
        .clk    (clk),
        .rst    (rst),

        .cnn_ready_in   (cnn_ready_in),
        .cnn_valid_in   (cnn_valid_in),
        .cnn_data_in    (cnn_data_in),

        .cnn_ready_out  (cnn_ready_out),
        .cnn_condition  (cnn_condition)
    );

    int fd;
    string line;
    bit valid;
    logic [DATA_WIDTH-1:0] hex;
    int count;

    initial begin
        count = SUBSAMPLE_FACTOR;
        fd = $fopen("../samples/adc_worn_cutting_tool_samples.hex", "r");
        cnn_ready_out = 1'b0;
        cnn_valid_in = 1'b0;
        cnn_data_in = {DATA_WIDTH{1'b0}};
        rst = 1'b1;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        

        while (!$feof(fd)) begin
            #(CLK_PERIOD);

            //cnn_ready_out <= $urandom_range(1'b0, 1'b1);
            cnn_ready_out <= 1'b1;
            if (cnn_ready_in | ~cnn_valid_in) begin
                //valid = $urandom_range(1'b0, 1'b1);
                valid = 1'b1;
                if (count < SUBSAMPLE_FACTOR) begin
                    count++;                    
                end else begin
                    count = 0;
                    $fgets(line, fd);
                end
                hex = line.atohex();
                cnn_data_in <= hex;
                cnn_valid_in <= valid;
            end
        end
        $fclose(fd);
        $stop;
    end


endmodule