////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       conv1d_layer.sv                                           //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Parallel 1-D convolution layer with AXI interface.        //
//                                                                            //
//                  Instantiates NUM_FILTERS parallel convolutions; weights   //
//                  and biases for each convolution are stored in their       //
//                  respective single port RAM. The weights and biases are    //
//                  registered after reset so that each convolution may       //
//                  access them in parallel.                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/sp_ram.v"
// synthesis translate_on

module conv1d_layer (
    clk,
    rst,

    conv1d_layer_ready_in,
    conv1d_layer_valid_in,
    conv1d_layer_data_in,

    conv1d_layer_ready_out,
    conv1d_layer_valid_out,
    conv1d_layer_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH        = 32;
    parameter WEIGHTS_INIT_FILE = "";
    parameter BIASES_INIT_FILE  = "";
    parameter NUM_FILTERS       = 32;
    parameter FILTER_SIZE       = 5;
    parameter PIPE_WIDTH        = 4;
    // position of the decimal point from the right 
    parameter FRACTION          = 24; 

    localparam FRACTIONAL_BITS = FRACTION;
    localparam INTEGER_BITS = (DATA_WIDTH-FRACTION);
    /* FRACTION Example

        localparam DATA_WIDTH = 12;
        localparam FRACTION = 9;

        some_data = 12'b001000000000 = 0b001.000000000 = 0d1.0

    */
    
    // capture the entire possible width of a multiplier output (no truncation)
    localparam LPM_OUT_WIDTH = DATA_WIDTH * 2; 

    // where the MSB will be when computing a multiplication
    // from the MSB -: DATA_WIDTH to correctly truncate the data
    localparam LPM_OUT_MSB = (LPM_OUT_WIDTH - 1) - (DATA_WIDTH - FRACTION); 

    localparam WEIGHTS_RAM_WIDTH = DATA_WIDTH * FILTER_SIZE; // weight RAM column width in bits
    localparam BIASES_RAM_WIDTH = DATA_WIDTH; // bias RAM column width in bits
    
    // RAM depth of both weight and bias RAM
    localparam RAM_DEPTH = NUM_FILTERS;

    // width in bits of the RAM address buses
    localparam RAM_ADDRESS_WIDTH = clog2(RAM_DEPTH); 

    localparam COUNTER_WIDTH = clog2(NUM_FILTERS);

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    conv1d_layer_ready_in;
    input logic                     conv1d_layer_valid_in;
    input logic [DATA_WIDTH-1:0]    conv1d_layer_data_in;

    // axi output interface
    input logic                     conv1d_layer_ready_out;
    output logic [NUM_FILTERS-1:0]  conv1d_layer_valid_out;
    output logic [DATA_WIDTH-1:0]   conv1d_layer_data_out   [0:NUM_FILTERS-1];

    // private signals
    logic [RAM_ADDRESS_WIDTH-1:0]   weight_address, bias_address;

    logic [WEIGHTS_RAM_WIDTH-1:0]   weight_ram_out;
    logic [BIASES_RAM_WIDTH-1:0]    bias_ram_out;

    // packed vectors for weights and biases
    logic [DATA_WIDTH-1:0] weights [0:NUM_FILTERS-1][0:FILTER_SIZE-1];
    logic [DATA_WIDTH-1:0] biases [0:NUM_FILTERS-1];

    // filter select logic registers (d for delay)
    logic [COUNTER_WIDTH-1:0] filter_select, filter_select_d1, filter_select_d2;
    logic filter_select_done, filter_select_done_d1, filter_select_done_d2;

    logic [NUM_FILTERS-1:0] conv1d_ready_in;
    logic                   conv1d_valid_in;

    assign weight_address = filter_select;
    assign bias_address = filter_select;
    /* if all the neurons are ready and the weights & biases have all been
    registered then the neuron layer is ready */
    assign conv1d_layer_ready_in = (&conv1d_ready_in) & filter_select_done_d2;

    assign conv1d_valid_in = conv1d_layer_valid_in & filter_select_done_d2;

    // weights RAM
    sp_ram #(
        .WIDTH      (WEIGHTS_RAM_WIDTH),
        .DEPTH      (RAM_DEPTH),
        .INIT_FILE  (WEIGHTS_INIT_FILE),
        .ADDRESS_WIDTH (RAM_ADDRESS_WIDTH)
    ) conv1d_weights (
        .address    (weight_address),
        .clock      (clk),
        .data       (), // unconnected (for now)
        .rden       (1'b1), // tied high (for now)
        .wren       (1'b0), // tied low (for now)
        .q          (weight_ram_out)
    );

    // biases RAM
    sp_ram #(
        .WIDTH      (BIASES_RAM_WIDTH),
        .DEPTH      (RAM_DEPTH),
        .INIT_FILE  (BIASES_INIT_FILE),
        .ADDRESS_WIDTH (RAM_ADDRESS_WIDTH)
    ) conv1d_biases (
	    .address    (bias_address),   
	    .clock      (clk),
	    .data       (), // unconnected (for now)
	    .rden       (1'b1), // tied high (for now)
	    .wren       (1'b0), // tied low (for now)
	    .q          (bias_ram_out)
    );
    
    // filter select logic
    always_ff @(posedge clk) begin
        if (rst) begin
            // initialise all registers to zero
            filter_select       <= {COUNTER_WIDTH{1'b0}};
            filter_select_d1    <= {COUNTER_WIDTH{1'b0}};
            filter_select_d2    <= {COUNTER_WIDTH{1'b0}};

            filter_select_done      <= 1'b0;
            filter_select_done_d1   <= 1'b0;
            filter_select_done_d2   <= 1'b0;
        end else begin
            if (filter_select < NUM_FILTERS-1) begin
                // count up to the number of convolutions
                filter_select <= filter_select + 1'b1;
            end else begin
                // flag when the count is done 
                filter_select_done <= 1'b1;
            end

            /* the RAM registers the input and output so delay the flag and 
            select line by two cycles */
            filter_select_d1 <= filter_select;
            filter_select_d2 <= filter_select_d1;

            filter_select_done_d1 <= filter_select_done;
            filter_select_done_d2 <= filter_select_done_d1;
        end
    end

    // register RAM output into vectors
    generate
        genvar weight;
        for (weight=0; weight<FILTER_SIZE; weight++) begin: WEIGHTS
            always_ff @(posedge clk) begin
                weights[filter_select_d2][(FILTER_SIZE-1)-weight] <= weight_ram_out[weight*DATA_WIDTH+:DATA_WIDTH];
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        biases[filter_select_d2] <= bias_ram_out;
    end

    generate
        genvar conv;

        for (conv=0; conv<NUM_FILTERS; conv++) begin: CONVOLUTION_1D

            // convolutions
            conv1d #(
                .DATA_WIDTH         (DATA_WIDTH),
                .FILTER_SIZE        (FILTER_SIZE),
                .PIPE_WIDTH         (PIPE_WIDTH),
                .FRACTION           (FRACTION)
            ) conv1d (
                .clk                (clk),
                .rst                (rst),

                .conv1d_ready_in    (conv1d_ready_in[conv]),
                .conv1d_valid_in    (conv1d_valid_in),
                .conv1d_data_in     (conv1d_layer_data_in),

                .conv1d_weights     (weights[conv]),
                .conv1d_bias        (biases[conv]),

                .conv1d_ready_out   (conv1d_layer_ready_out),
                .conv1d_valid_out   (conv1d_layer_valid_out[conv]),
                .conv1d_data_out    (conv1d_layer_data_out[conv])
            );
        end
    endgenerate

endmodule