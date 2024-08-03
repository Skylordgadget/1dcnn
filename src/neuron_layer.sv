////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       neuron_layer.sv                                           //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Parallel neuron layer with AXI interface.                 //
//                                                                            //
//                  Instantiates NUM_NEURONS parallel neurons; weights        //
//                  and biases for each neuron are stored in their            //
//                  respective single port RAM. The weights and biases are    //
//                  registered after reset so that each neuron may            //
//                  access them in parallel.                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
`include "./../ip/sp_ram.v"
// synthesis translate_on

module neuron_layer (
    clk,
    rst,

    neuron_layer_ready_in,
    neuron_layer_valid_in,
    neuron_layer_data_in,

    neuron_layer_ready_out,
    neuron_layer_valid_out,
    neuron_layer_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH        = 32; // width of the incoming data
    parameter WEIGHTS_INIT_FILE = "";
    parameter BIASES_INIT_FILE  = "";
    parameter NUM_NEURONS       = 32;
    parameter NEURON_INPUTS     = 5;
    parameter PIPE_WIDTH        = 4;
    // position of the decimal point from the right
    parameter FRACTION          = 24;  

    localparam NUM_FRACTION_LSBS = FRACTION;
    localparam NUM_FRACTION_MSBS = (DATA_WIDTH-FRACTION);
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

    // column width in bits of both weight and bias RAM
    localparam RAM_WIDTH = DATA_WIDTH * NUM_NEURONS;

    localparam WEIGHTS_RAM_DEPTH = NEURON_INPUTS; // weight RAM row depth
    localparam BIASES_RAM_DEPTH = 1; // bias RAM row depth (always 1)

    // width in bits of the RAM address buses
    localparam WEIGHTS_ADDRESS_WIDTH = clog2(WEIGHTS_RAM_DEPTH); 
    localparam BIASES_ADDRESS_WIDTH = clog2(BIASES_RAM_DEPTH);

    localparam COUNTER_WIDTH = clog2(NEURON_INPUTS);

    // clock and reset interface
    input logic                     clk;
    input logic                     rst;

    // axi input interface
    output logic                    neuron_layer_ready_in;
    input logic                     neuron_layer_valid_in;
    input logic [DATA_WIDTH-1:0]    neuron_layer_data_in    [0:NEURON_INPUTS-1];

    // axi output interface
    input logic                     neuron_layer_ready_out;
    output logic [NUM_NEURONS-1:0]  neuron_layer_valid_out;
    output logic [DATA_WIDTH-1:0]   neuron_layer_data_out   [0:NUM_NEURONS-1];

    // private signals
    logic [WEIGHTS_ADDRESS_WIDTH-1:0]   weight_address;
    logic [BIASES_ADDRESS_WIDTH-1:0]    bias_address;

    logic [RAM_WIDTH-1:0] weight_ram_out, bias_ram_out;

    // packed vectors for weights and biases
    logic [DATA_WIDTH-1:0] weights [0:NUM_NEURONS-1][0:NEURON_INPUTS-1];
    logic [DATA_WIDTH-1:0] biases [0:NUM_NEURONS-1];

    // weight select logic registers (d for delay)
    logic [COUNTER_WIDTH-1:0] weight_select, weight_select_d1, weight_select_d2;
    logic weight_select_done, weight_select_done_d1, weight_select_done_d2;

    logic [NUM_NEURONS-1:0] neuron_ready_in;

    assign weight_address = weight_select;

    /* if all the neurons are ready and the weights & biases have all been
    registered then the neuron layer is ready */
    assign neuron_layer_ready_in = (&neuron_ready_in) & weight_select_done_d2;

    // weights RAM
    sp_ram #(
        .WIDTH      (RAM_WIDTH),
        .DEPTH      (WEIGHTS_RAM_DEPTH),
        .INIT_FILE  (WEIGHTS_INIT_FILE),
        .ADDRESS_WIDTH (WEIGHTS_ADDRESS_WIDTH)
    ) neuron_weights (
        .address    (weight_address),
        .clock      (clk),
        .data       (), // unconnected (for now)
        .rden       (1'b1), // tied high (for now)
        .wren       (1'b0), // tied low (for now)
        .q          (weight_ram_out)
    );

    // biases RAM
    sp_ram #(
        .WIDTH      (RAM_WIDTH),
        .DEPTH      (BIASES_RAM_DEPTH),
        .INIT_FILE  (BIASES_INIT_FILE),
        .ADDRESS_WIDTH (BIASES_ADDRESS_WIDTH)
    ) neuron_biases (
	    .address    (bias_address),   
	    .clock      (clk),
	    .data       (), // unconnected (for now)
	    .rden       (1'b1), // tied high (for now)
	    .wren       (1'b0), // tied low (for now)
	    .q          (bias_ram_out)
    );
    
    // weight select logic
    always_ff @(posedge clk) begin
        if (rst) begin
            // initialise all registers to zero
            weight_select       <= {COUNTER_WIDTH{1'b0}};
            weight_select_d1    <= {COUNTER_WIDTH{1'b0}};
            weight_select_d2    <= {COUNTER_WIDTH{1'b0}};

            weight_select_done      <= 1'b0;
            weight_select_done_d1   <= 1'b0;
            weight_select_done_d2   <= 1'b0;

            bias_address <= {BIASES_ADDRESS_WIDTH{1'b0}};
        end else begin
            if (weight_select < NEURON_INPUTS-1) begin
                // count up to the number of inputs each neuron has
                weight_select <= weight_select + 1'b1;
            end else begin
                // flag when the count is done 
                weight_select_done <= 1'b1;
            end

            /* the RAM registers the input and output so delay the flag and 
            select line by two cycles */
            weight_select_d1 <= weight_select;
            weight_select_d2 <= weight_select_d1;

            weight_select_done_d1 <= weight_select_done;
            weight_select_done_d2 <= weight_select_done_d1;
        end
    end

    generate
        genvar nrn;

        for (nrn=0; nrn<NUM_NEURONS; nrn++) begin: NEURONS
            always_ff @(posedge clk) begin
                // register RAM output into vectors
                weights[(NUM_NEURONS-1)-nrn][weight_select_d2] <= weight_ram_out[nrn*DATA_WIDTH+:DATA_WIDTH];
                biases[(NUM_NEURONS-1)-nrn] <= bias_ram_out[nrn*DATA_WIDTH+:DATA_WIDTH];
            end

            // neurons
            neuron #(
                .DATA_WIDTH         (DATA_WIDTH),
                .NUM_INPUTS         (NEURON_INPUTS),
                .PIPE_WIDTH         (PIPE_WIDTH),
                .FRACTION           (FRACTION)
            ) neuron (
                .clk                (clk),
                .rst                (rst),

                .neuron_ready_in    (neuron_ready_in[nrn]),
                .neuron_valid_in    (neuron_layer_valid_in & weight_select_done_d2),
                .neuron_data_in     (neuron_layer_data_in),

                .neuron_weights     (weights[nrn]),
                .neuron_bias        (biases[nrn]),

                .neuron_ready_out   (neuron_layer_ready_out),
                .neuron_valid_out   (neuron_layer_valid_out[nrn]),
                .neuron_data_out    (neuron_layer_data_out[nrn])
            );
        end
    endgenerate

endmodule