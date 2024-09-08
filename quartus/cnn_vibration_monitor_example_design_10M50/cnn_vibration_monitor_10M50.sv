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

    // subsampler parameter
    localparam SUBSAMPLE_FACTOR = 400;

    // ADC to voltage parameters
    /* this example design uses the Max 10 development kit and on-chip ADC of 
    the Max 10 FPGA. The ADC refrence voltage is set at 0V to +2.5V.

    To use as much of the ADC resultion as possible I have multiplied all the
    samples by 24 and then added a positive bias of 1.25V.

    The adc2v core unbiases and downscales the values.

    ADC_REF is the reference voltage of the ADC (2.5V). The network
    was trained on values in mV so ADC_REF is set to 2500.

    BIAS is added with the voltage to unbias it. In this case, the bias is
    -1250mV. -1250 is represented in two's compliment fixed-point format.

    SCALE_FACTOR is multiplied with the voltage to unscale it. In this case,
    the scale factor is 1/24. 1/24 is represented in two's compliment 
    fixed-point format.

    NOTE: bias is applied before the scale factor
    */

    localparam ADC_REF      = 2500; 
    localparam BIAS         = 32'hfffffb1e;
    localparam SCALE_FACTOR = 32'h000aaaab; 

    // convolution layer parameters
    localparam CONV_BIASES_INIT_FILE    = "./../../test/weights/conv1d_biases_8I24F.hex";
    localparam CONV_WEIGHTS_INIT_FILE   = "./../../test/weights/conv1d_weights_8I24F.hex";
    localparam NUM_FILTERS              = 8;
    localparam FILTER_SIZE              = 5;

    // global average pool parameters
    localparam POOL_SIZE    = 256;

    // fully connected layer parameters
    localparam NEURON_BIASES_INIT_FILE  = "./../../test/weights/fc_biases_8I24F.hex";
    localparam NEURON_WEIGHTS_INIT_FILE = "./../../test/weights/fc_weights_8I24F.hex";
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

    logic                           adc_command_valid;
    logic [ADC_CHANNEL_WIDTH-1:0]   adc_command_channel;
    logic                           adc_command_startofpacket;
    logic                           adc_command_endofpacket;

	logic 		 			        adc_response_valid, adc_response_valid_r;
	logic [ADC_WIDTH-1:0] 	        adc_response_data,  adc_response_data_r;

	logic 					cnn_ready_in;
	logic 					cnn_valid_in;
	logic [ADC_WIDTH-1:0] 	cnn_data_in;

	logic 					cnn_condition;
    logic                   cnn_ready_out;

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
            adc_command_channel         <= {ADC_CHANNEL_WIDTH{1'b0}} + 1'b1; // channel 1
            adc_command_startofpacket   <= 1'b0;
            adc_command_endofpacket     <= 1'b0;

            cnn_ready_out <= 1'b0;
		end else begin
            adc_command_valid <= 1'b1;
            cnn_ready_out <= 1'b1;
            // register adc response
			adc_response_valid_r    <= adc_response_valid;
			adc_response_data_r     <= adc_response_data;

            cnn_valid_in <= adc_response_valid_r;
            cnn_data_in <= adc_response_data_r;
		end
	end    

    assign led = {cnn_condition, button};

/// CONVOLUTIONAL NEURAL NETWORK ///////////////////////////////////////////////

    m10_cnn1d #(
        .DATA_WIDTH                 (DATA_WIDTH),
        .FRACTION                   (FRACTION),
        .PIPE_WIDTH                 (PIPE_WIDTH),
        
        .SUBSAMPLE_FACTOR           (SUBSAMPLE_FACTOR),
        
        .ADC_REF                    (ADC_REF),
        .BIAS                       (BIAS),
        .SCALE_FACTOR               (SCALE_FACTOR),
        
        .CONV_WEIGHTS_INIT_FILE     (CONV_WEIGHTS_INIT_FILE),
        .CONV_BIASES_INIT_FILE      (CONV_BIASES_INIT_FILE),
        .NUM_FILTERS                (NUM_FILTERS),
        .FILTER_SIZE                (FILTER_SIZE),

        .POOL_SIZE                  (POOL_SIZE),
        
        .NEURON_WEIGHTS_INIT_FILE   (NEURON_WEIGHTS_INIT_FILE),
        .NEURON_BIASES_INIT_FILE    (NEURON_BIASES_INIT_FILE),
        .NUM_NEURONS                (NUM_NEURONS)
    ) cnn1d (
        .clk                        (clk),
        .rst                        (rst),

        .cnn_ready_in               (cnn_ready_in),
        .cnn_valid_in               (cnn_valid_in),
        .cnn_data_in                (cnn_data_in),

        .cnn_ready_out              (cnn_ready_out),
        .cnn_condition              (cnn_condition)
    );

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