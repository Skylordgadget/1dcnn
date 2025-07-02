////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       accum_single_sample.sv                                                  //
//  Author:         Shamin                                         //
//  Description:    Accumulator with AXI interface.                           //
//                                                                            //
//                  Accumulator = Accumulator + Data In                        //
//                  The accumulator is reset when the number of valid         //
//                  accum_data_in beats reaches POOL_SIZE. Only valid beats   //
//                  are summed to avoid poisoning the pool.                   //
//  TODO:           - Add a pipeline stage to remove dead beats               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

module accum_single_sample (
    clk,
    rst,

    accum_ready_in,
    accum_valid_in,
    accum_data_in,

    accum_ready_out,
    accum_valid_out,
    accum_data_out

);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter POOL_SIZE = 10;

    localparam COUNTER_WIDTH = clog2(POOL_SIZE);
    // accumulator bit width is extended by the counter width to avoid overflows
    localparam ACCUMULATOR_WIDTH =  DATA_WIDTH + COUNTER_WIDTH;
    
    // clock and reset interface
    input logic                             clk;
    input logic                             rst;
    
    // axi input interface
    output logic                            accum_ready_in;
    input logic                             accum_valid_in;
    input logic [DATA_WIDTH-1:0]            accum_data_in;

    // axi output interface
    input logic                             accum_ready_out;
    output logic                            accum_valid_out;
    output logic [ACCUMULATOR_WIDTH-1:0]    accum_data_out;


    // shift register to save the input data in
    logic [DATA_WIDTH-1:0]                  accum_reg [0:POOL_SIZE-1];

    // private signals
    logic [ACCUMULATOR_WIDTH-1:0] accumulator;
    logic accum_valid_in_d1, accum_valid_in_d2;

    // reduce logic
    integer i, j;
    always_ff @(posedge clk) begin
        if (rst) begin
            // initialise all registers
            accumulator <= {ACCUMULATOR_WIDTH{1'b0}};
            accum_valid_out <= 1'b0;
            accum_valid_in_d1 <= 1'b0;
            accum_valid_in_d2 <= 1'b0;
            accum_data_out <= {ACCUMULATOR_WIDTH{1'b0}};
            // initial value of zero saved in registers	   
	        for (i=0; i<POOL_SIZE; i++) begin
                accum_reg[i] <= {DATA_WIDTH{1'b0}};
            end
        end else begin


             // handle handshake at the input 
            if (accum_ready_in) begin

                if (accum_valid_in) begin
                    for (j=POOL_SIZE-1; j>0; j--) begin
                        accum_reg[j] <= accum_reg[j-1];
                    end
                    accum_reg[0] <= accum_data_in;    
                end
				accum_valid_in_d1    <= accum_valid_in;
                
                // (newest data + accumulator) - oldest data
                if (accum_valid_in_d1) begin
                    accumulator  <= (accumulator + accum_reg[0]) - accum_reg[POOL_SIZE-1];
                end
                accum_valid_in_d2    <= accum_valid_in_d1;
                    
                accum_data_out          <= accumulator;
                accum_valid_out         <= accum_valid_in_d2;
            end
        end
    end    

    assign accum_ready_in = accum_ready_out | ~accum_valid_out;

endmodule