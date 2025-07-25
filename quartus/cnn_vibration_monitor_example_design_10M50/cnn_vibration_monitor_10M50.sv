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
    led,

    pmoda_io
);

    import cnn1d_pkg::*;

/// PARAMETERS /////////////////////////////////////////////////////////////////

    // general parameters
    localparam DATA_WIDTH   = 24;
    localparam FRACTION     = 12; // position of the decimal point from the right 
    localparam PIPE_WIDTH   = 4;

    // subsampler parameter
    localparam SUBSAMPLE_FACTOR = 400;

    // convolution layer parameters
    localparam CONV_BIASES_INIT_FILE    = "./../../test/weights/conv1d_1_biases_12I12F.hex";
    localparam CONV_WEIGHTS_INIT_FILE   = "./../../test/weights/conv1d_1_weights_12I12F.hex";
    localparam NUM_FILTERS              = 2;
    localparam FILTER_SIZE              = 8;

    // global average pool parameters
    localparam POOL_SIZE    = 512;

    // fully connected layer parameters
    localparam FC_1_INPUTS  = 2;
    localparam FC_1_NEURONS = 8; 
    localparam FC_1_PARAMS  = "./../../test/weights/fc_parameters_1_12I12F.hex";
    localparam FC_2_INPUTS  = 8;
    localparam FC_2_NEURONS = 2;
    localparam FC_2_PARAMS  = "./../../test/weights/fc_parameters_2_12I12F.hex";

    localparam ADC_CHANNELS = 2;

////////////////////////////////////////////////////////////////////////////////

/// I/O ////////////////////////////////////////////////////////////////////////

    input logic                             clk50;
    output logic [2:0]                      led;

    output logic [7:0]                      pmoda_io;

////////////////////////////////////////////////////////////////////////////////

/// PRIVATE SIGNALS ////////////////////////////////////////////////////////////

    // private signals
	logic pll_locked, pll_locked_r1, pll_locked_r2, rst_n, rst;
	logic clk10, clk;

    logic                           adc_c_valid;
    logic                           adc_c_ready;
    logic [ADC_CHANNEL_WIDTH-1:0]   adc_c_channel;
    logic                           adc_c_sop;
    logic                           adc_c_eop;
	
    logic 		 			        adc_r_valid;
    logic [ADC_CHANNEL_WIDTH-1:0]   adc_r_channel;
	logic [ADC_WIDTH-1:0] 	        adc_r_data;
    logic                           adc_r_sop;
    logic                           adc_r_eop;
    

    logic                           cnn_ready_in;
    logic                           cnn_valid_in;
    logic [ADC_WIDTH-1:0]           cnn_data_in [0:1];

    logic                           cnn_ready_out;
    logic                           cnn_valid_out;
    logic                           cnn_condition;
	 
	 logic [26:0] led_counter;
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
			led_counter <= '0;
			led[1:0] <= 2'b10;
		end else begin
			if (led_counter < 99999999) begin
				led_counter <= led_counter + 1'b1;
			end else begin
				led[1:0] <= ~led[1:0];
				led_counter <= '0;
			end
		end
	end

    assign led[2] = ~cnn_condition;

/// ADC to AXI /////////////////////////////////////////////////////////////////

    m10_adc2axi #(
        .CHANNELS   (ADC_CHANNELS)
    ) adc2axi (
        .clk        (clk),
        .rst        (rst),

        .adc_c_valid    (adc_c_valid),
        .adc_c_ready    (adc_c_ready),
        .adc_c_channel  (adc_c_channel),
        .adc_c_sop      (adc_c_sop),
        .adc_c_eop      (adc_c_eop),

        .adc_r_valid    (adc_r_valid),
        .adc_r_channel  (adc_r_channel),
        .adc_r_data     (adc_r_data),
        .adc_r_sop      (adc_r_sop),
        .adc_r_eop      (adc_r_eop),

        .adc_ready_out  (cnn_ready_in),
        .adc_valid_out  (cnn_valid_in),
        .adc_data_out   (cnn_data_in)
    );

////////////////////////////////////////////////////////////////////////////////

/// CONVOLUTIONAL NEURAL NETWORK ///////////////////////////////////////////////

    m08_cnn1d #(
        .DATA_WIDTH                 (DATA_WIDTH),
        .FRACTION                   (FRACTION),
        .PIPE_WIDTH                 (PIPE_WIDTH),
        
        .SUBSAMPLE_FACTOR           (SUBSAMPLE_FACTOR),
        
        .CONV_WEIGHTS_INIT_FILE     (CONV_WEIGHTS_INIT_FILE),
        .CONV_BIASES_INIT_FILE      (CONV_BIASES_INIT_FILE),
        .NUM_FILTERS                (NUM_FILTERS),
        .FILTER_SIZE                (FILTER_SIZE),

        .POOL_SIZE                  (POOL_SIZE),
        
        .FC_1_INPUTS                (FC_1_INPUTS),
        .FC_1_NEURONS               (FC_1_NEURONS),
        .FC_1_PARAMS                (FC_1_PARAMS),
        .FC_2_INPUTS                (FC_2_INPUTS),
        .FC_2_NEURONS               (FC_2_NEURONS),
        .FC_2_PARAMS                (FC_2_PARAMS)
    ) cnn1d (
        .clk                        (clk),
        .rst                        (rst),

        .cnn_ready_in               (cnn_ready_in),
        .cnn_valid_in               (cnn_valid_in),
        .cnn_data_in                (cnn_data_in),

        .cnn_ready_out              (cnn_ready_out),
        .cnn_valid_out              (cnn_valid_out),
        .cnn_condition              (cnn_condition)
    );

    assign pmoda_io[0] = clk;
    //assign pmoda_io[1] = v_ready;
    //assign pmoda_io[2] = v_valid;
    //assign pmoda_io[3] = r_ready;
    //assign pmoda_io[4] = r_valid;
    assign pmoda_io[5] = cnn_ready_out;
    assign pmoda_io[6] = cnn_valid_out;
    assign pmoda_io[7] = cnn_condition;
    assign cnn_ready_out = 1'b1;
	
////////////////////////////////////////////////////////////////////////////////

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
		.modular_adc_0_command_valid            (adc_c_valid),         
		.modular_adc_0_command_channel          (adc_c_channel),       
		.modular_adc_0_command_startofpacket    (adc_c_sop), 
		.modular_adc_0_command_endofpacket      (adc_c_eop),   
		.modular_adc_0_command_ready            (adc_c_ready),    

        // adc response interface
		.modular_adc_0_response_valid           (adc_r_valid),        
		.modular_adc_0_response_channel         (adc_r_channel),      
		.modular_adc_0_response_data            (adc_r_data),         
		.modular_adc_0_response_startofpacket   (adc_r_sop),
		.modular_adc_0_response_endofpacket     (adc_r_eop),        

        // unused AVMM slave interface
		.altpll_0_pll_slave_read                (),  
		.altpll_0_pll_slave_write               (),            
		.altpll_0_pll_slave_address             (),          
		.altpll_0_pll_slave_readdata            (),         
		.altpll_0_pll_slave_writedata           ()         
	);

////////////////////////////////////////////////////////////////////////////////

endmodule