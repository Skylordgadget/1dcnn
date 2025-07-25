module m10_adc2axi (
    clk,
    rst,

    adc_c_valid,
    adc_c_ready,
    adc_c_channel,
    adc_c_sop,
    adc_c_eop,

    adc_r_valid,
    adc_r_channel,
    adc_r_data,
    adc_r_sop,
    adc_r_eop,

    adc_ready_out,
    adc_valid_out,
    adc_data_out
);
    import cnn1d_pkg::*;

    parameter CHANNELS = 17;

    // clock and reset interface
    input   logic                           clk;
    input   logic                           rst;
    
    output  logic                           adc_c_valid;
    input   logic                           adc_c_ready;
    output  logic [ADC_CHANNEL_WIDTH-1:0]   adc_c_channel;
    output  logic                           adc_c_sop;
    output  logic                           adc_c_eop;

    input   logic 		 			        adc_r_valid;
    input   logic [ADC_CHANNEL_WIDTH-1:0]   adc_r_channel; // unused
	input   logic [ADC_WIDTH-1:0] 	        adc_r_data;
    input   logic                           adc_r_sop; // unused
    input   logic                           adc_r_eop; // unused

    input   logic                           adc_ready_out;
    output  logic                           adc_valid_out;
    output  logic [ADC_WIDTH-1:0]           adc_data_out    [0:CHANNELS-1];

    always_ff @(posedge clk) begin
        if (rst) begin
            adc_c_eop <= 1'b0;
            adc_c_sop <= 1'b1; 
            adc_c_valid <= 1'b1;
            adc_c_channel <= {ADC_CHANNEL_WIDTH{1'b0}} + 1'b1; // default channel 1
        end else begin

            if (adc_c_ready) begin
                if (adc_c_channel >= CHANNELS-1) begin
                    adc_c_eop <= 1'b1;
                end

                if (adc_c_eop) begin
                    adc_c_channel <= {ADC_CHANNEL_WIDTH{1'b0}} + 1'b1;
                    adc_c_eop <= 1'b0;
                    adc_c_sop <= 1'b1;
                end else begin
                    adc_c_channel <= adc_c_channel + 1'b1;
                    adc_c_sop <= 1'b0;
                end
            end
        end
    end

    s2p #(
        .DATA_WIDTH     (ADC_WIDTH),
        .NUM_ELEMENTS   (CHANNELS)
    ) s2p (
        .clk                (clk),
        .rst                (rst),
        
        .s2p_ready_in       (), // unconnected (valid data beats might be dropped, in future use a fifo)
        .s2p_valid_in       (adc_r_valid),
        .s2p_serial_in      (adc_r_data),

        .s2p_ready_out      (adc_ready_out),
        .s2p_valid_out      (adc_valid_out),
        .s2p_parallel_out   (adc_data_out)
    );
endmodule