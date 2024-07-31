// synthesis translate_off
`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on

module accum (
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
    localparam ACCUMULATOR_WIDTH =  DATA_WIDTH + COUNTER_WIDTH;

    input logic                             clk;
    input logic                             rst;

    output logic                            accum_ready_in;
    input logic                             accum_valid_in;
    input logic [DATA_WIDTH-1:0]            accum_data_in;

    input logic                             accum_ready_out;
    output logic                            accum_valid_out;
    output logic [ACCUMULATOR_WIDTH-1:0]    accum_data_out;

    logic [ACCUMULATOR_WIDTH-1:0] accumulator;
    logic [COUNTER_WIDTH-1:0] count;

    // reduce logic
    always_ff @(posedge clk) begin
        if (rst) begin
            // initialise all registers
            accumulator <= {ACCUMULATOR_WIDTH{1'b0}};
            count <= {COUNTER_WIDTH{1'b0}};
            accum_valid_out <= 1'b0;
            accum_ready_in <= 1'b1;
            accum_data_out <= {ACCUMULATOR_WIDTH{1'b0}};
        end else begin
            /* when there is a handshake at the output, deassert valid to prevent
            duplicates and invalid data being clocked out */
            if (accum_valid_out && accum_ready_out) begin
                accum_valid_out <= 1'b0;
                accum_ready_in <= 1'b1;
            end

            // handle handshake at the input 
            if (accum_valid_in && accum_ready_in) begin
                if (count < POOL_SIZE-1) begin
                    // accumulate and increment the counter
                    accumulator <= accumulator + accum_data_in;
                    count <= count + 1'b1;
                end else begin
                    // reset the accumulator
                    accumulator <= {ACCUMULATOR_WIDTH{1'b0}};
                    // clock out the final result
                    accum_data_out <= accumulator + accum_data_in;
                    // reset the count
                    count <= {COUNTER_WIDTH{1'b0}};
                    // data is valid, reserve a cycle for resetting
                    accum_valid_out <= 1'b1;
                    accum_ready_in <= 1'b0;
                end
            end
        end
    end    

endmodule