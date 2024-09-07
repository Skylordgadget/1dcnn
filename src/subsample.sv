////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Filename:       subsample.sv                                              //
//  Author:         Harry Kneale-Roby                                         //
//  Description:    
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on

module subsample (
    clk,
    rst,

    subsample_ready_in,
    subsample_valid_in,
    subsample_data_in,

    subsample_ready_out,
    subsample_valid_out,
    subsample_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 12;
    parameter SUBSAMPLE_FACTOR = 400;    

    localparam COUNTER_WIDTH = clog2(SUBSAMPLE_FACTOR);
    // subsampleulator bit width is extended by the counter width to avoid overflows
    
    // clock and reset interface
    input logic                             clk;
    input logic                             rst;
    
    // axi input interface
    output logic                            subsample_ready_in;
    input logic                             subsample_valid_in;
    input logic [DATA_WIDTH-1:0]            subsample_data_in;

    // axi output interface
    input logic                             subsample_ready_out;
    output logic                            subsample_valid_out;
    output logic [DATA_WIDTH-1:0]           subsample_data_out;

    // private signals
    logic [COUNTER_WIDTH-1:0] count;

    // reduce logic
    always_ff @(posedge clk) begin
        if (rst) begin
            // initialise all registers
            count <= {COUNTER_WIDTH{1'b0}};
            subsample_valid_out <= 1'b0;
            subsample_ready_in <= 1'b1;
            subsample_data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            /* when there is a handshake at the output, deassert valid to prevent
            duplicates and invalid data being clocked out */
            if (subsample_valid_out && subsample_ready_out) begin
                subsample_valid_out <= 1'b0;
                subsample_ready_in <= 1'b1;
            end

            // handle handshake at the input 
            if (subsample_valid_in && subsample_ready_in) begin
                if (count < SUBSAMPLE_FACTOR-1) begin
                    count <= count + 1'b1;
                end else begin
                    // clock out the final result
                    subsample_data_out <= subsample_data_in;
                    // reset the count
                    count <= {COUNTER_WIDTH{1'b0}};
                    // data is valid, reserve a cycle for resetting
                    subsample_valid_out <= 1'b1;
                    subsample_ready_in <= 1'b0;
                end
            end
        end
    end    

endmodule