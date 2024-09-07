////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       cnn_vibration_monitor_10M50.sv                            //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    Convolutional neural network 10M50 Quartus project top-   //
//                  level design entity.                                      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module cnn_vibration_monitor_10M50 (
    clk50,
    button,
    led
);

    import cnn1d_pkg::*;

/// PARAMETERS /////////////////////////////////////////////////////////////////

    // general parameters
    localparam DATA_WIDTH   = 32;
    localparam FRACTION     = 24; // position of the decimal point from the right 
    localparam PIPE_WIDTH   = 4;

    // convolution layer parameters
    localparam CONV_BIASES_INIT_FILE    = "./../test/weights/conv1d_biases_8I24F.hex";
    localparam CONV_WEIGHTS_INIT_FILE   = "./../test/weights/conv1d_weights_8I24F.hex";
    localparam NUM_FILTERS              = 8;
    localparam FILTER_SIZE              = 5;

    // global average pool parameters
    localparam POOL_SIZE    = 256;

    // fully connected layer parameters
    localparam NEURON_BIASES_INIT_FILE  = "./../test/weights/fc_biases_8I24F.hex";
    localparam NEURON_WEIGHTS_INIT_FILE = "./../test/weights/fc_weights_8I24F.hex";
    localparam NUM_NEURONS              = 2;

////////////////////////////////////////////////////////////////////////////////

/// I/O ////////////////////////////////////////////////////////////////////////

    // MAX 10 development kit I/O
    input logic                             clk50;
    input logic [M10_DEV_KIT_BUTTONS-1:0]   button;
    output logic [M10_DEV_KIT_LEDS-1:0]     led;

////////////////////////////////////////////////////////////////////////////////

/// PRIVATE SIGNALS ////////////////////////////////////////////////////////////

    // private signals
	logic pll_locked, pll_locked_r1, pll_locked_r2, rst_n, rst;
	logic clk10, clk;

    logic                       adc_command_valid;
    logic [ADC_WIDTH_CLOG2-1:0] adc_command_channel;
    logic                       adc_command_startofpacket;
    logic                       adc_command_endofpacket;

	logic 		 			    adc_response_valid, adc_response_valid_r;
	logic [ADC_WIDTH-1:0] 	    adc_response_data,  adc_response_data_r;

	logic 					cnn_ready_in;
	logic 					cnn_valid_in;
	logic [DATA_WIDTH-1:0] 	cnn_data_in;

	logic 					cnn_condition;

////////////////////////////////////////////////////////////////////////////////

	assign rst = ~rst_n;

	always_ff @(posedge clk) begin
        // mitigate metastability on reset
		pll_locked_r1 <= pll_locked;
		pll_locked_r2 <= pll_locked_r1;
		rst_n <= pll_locked_r2;
	end

	always_ff @(posedge clk) begin
		if (rst) begin
			adc_response_valid_r <= 1'b0;
			adc_response_data_r <= 1'b0;

            adc_command_valid           <= 1'b0;
            adc_command_channel         <= {ADC_WIDTH_CLOG2{1'b0}};
            adc_command_startofpacket   <= 1'b1;
            adc_command_endofpacket     <= 1'b1;
		end else begin
            adc_command_valid <= 1'b1;
            // register adc response
			adc_response_valid_r <= adc_response_valid;
			adc_response_data_r <= adc_response_data;
		end
	end    

    assign led = {cnn_condition, button};

/// ADC PLATFORM DESIGNER INSTANCE /////////////////////////////////////////////

	adc u0 (
        // 50MHz clock bridge
		.clk_clk                                (clk50),                             
		.reset_reset_n                          (rst_n),  

        // main clock
        .altpll_0_c1_clk                        (clk),

        // pll locked
        .altpll_0_locked_conduit_export         (pll_locked),
        
        // adc sample clock and reset interface
        .modular_adc_0_clock_clk                (clk),             
		.modular_adc_0_reset_sink_reset_n       (rst_n), 
        
        // pll locked
        .modular_adc_0_adc_pll_locked_export    (pll_locked),

        // adc command interface
		.modular_adc_0_command_valid            (adc_command_valid),         
		.modular_adc_0_command_channel          (adc_command_channel),       
		.modular_adc_0_command_startofpacket    (adc_command_startofpacket), 
		.modular_adc_0_command_endofpacket      (adc_command_endofpacket),   
		.modular_adc_0_command_ready            (),    

        // adc response interface
		.modular_adc_0_response_valid           (adc_response_valid),        
		.modular_adc_0_response_channel         (),      
		.modular_adc_0_response_data            (adc_response_data),         
		.modular_adc_0_response_startofpacket   (),
		.modular_adc_0_response_endofpacket     (),        

        // unused AVMM slave interface
		.altpll_0_pll_slave_read                (),  
		.altpll_0_pll_slave_write               (),            
		.altpll_0_pll_slave_address             (),          
		.altpll_0_pll_slave_readdata            (),         
		.altpll_0_pll_slave_writedata           ()         
	);

////////////////////////////////////////////////////////////////////////////////

endmodule