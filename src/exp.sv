// exp is really slow and expensive, uses the taylor series approximation!!
// this doesn't work yet!!
// TODO: get this working, the problem is that there needs to either be a delay
// to prevent data getting in while exp_data_in gets through POW or a pipeline
// to delay the data that gets through POW the earliest. Delaying is logically
// complex and using a pipeline uses lots of registers; it is also complex to 
// precalculate pipeline widths

// synthesis translate_off
`timescale 1ns / 1ns

`include "./../pkg/cnn1d_pkg.sv"
// synthesis translate_on

module exp (
    clk,
    rst,

    exp_ready_in,
    exp_valid_in,
    exp_data_in,

    exp_ready_out,
    exp_valid_out,
    exp_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH = 32;
    parameter PRECISION = 4;
    parameter LPM_PIPE_WIDTH = 4;
    parameter FRACTION = 24;

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
    
    localparam NUM_DIVIDES = PRECISION - 2;

    // total propagation delay of the module
    localparam EXP_DELAY = ((PRECISION-1) * LPM_PIPE_WIDTH) + LPM_PIPE_WIDTH + (NUM_DIVIDES-1);

    localparam DELAY_COUNTER_WIDTH = clog2(EXP_DELAY);

    input logic clk;
    input logic rst;

    output logic exp_ready_in;
    input logic exp_valid_in;
    input logic [DATA_WIDTH-1:0] exp_data_in;

    input logic exp_ready_out;
    output logic exp_valid_out;
    output logic [DATA_WIDTH-1:0] exp_data_out;

    logic [DATA_WIDTH-1:0] factorial [0:SUPPORTED_PRECISION-1];

    logic [NUM_DIVIDES-1:0] pow_ready_in;

    logic [NUM_DIVIDES-1:0] pow_valid_out;
    logic [NUM_DIVIDES-1:0] pow_ready_out;
    logic [DATA_WIDTH-1:0]  pow_data_out [0:NUM_DIVIDES-1];

    logic [NUM_DIVIDES-1:0] div_valid_out;
    logic [DATA_WIDTH-1:0] div_data_out [0:NUM_DIVIDES-1];

    logic [DATA_WIDTH-1:0] div_sum [0:NUM_DIVIDES-1];

    logic [DATA_WIDTH-1:0] exp_data_in_reg;
    logic [DELAY_COUNTER_WIDTH-1:0] count; 

    // state machine states
    typedef enum { 
        FLUSH,
        RUNNING,
        IDLE
    } state_t;

    state_t state, next_state;

    /* while the system is idle, allow inputs
    TODO it *is* possible to eliminate the need for an idle state */
    assign exp_ready_in = (state == IDLE) & (&pow_ready_in);
    
    // clock in next_state
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end 

    // determine next_state
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin /* if the incoming data is valid then transition to 
                running (valid && ready) */
                if (exp_valid_in) begin
                    next_state = RUNNING;
                end
            end
            RUNNING: begin /* while running, if the count finishes and the 
                downstream module is ready then transition to flush */
                if ((count == EXP_DELAY-1) && exp_ready_out) begin
                    next_state = FLUSH;
                end
            end 
            FLUSH: begin /* if the downstream module is still ready 
            transition to idle */
                if (exp_ready_out) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= {DELAY_COUNTER_WIDTH{1'b0}};
            exp_valid_out <= 1'b0;
            exp_data_in_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    if (exp_valid_in) begin
                        // capture the next available valid parallel data
                        exp_data_in_reg <= exp_data_in;
                    end
                end
                RUNNING: begin
                    if (exp_ready_out) begin
                        // outgoing data is always valid while running
                        exp_valid_out <= 1'b0;
                        count <= count + 1'b1;
                    end 
                end
                FLUSH: begin
                    if (exp_ready_out) begin
                        // only send valid low when next ready
                        exp_valid_out <= 1'b1;
                        // flush the counter
                        count <= {DELAY_COUNTER_WIDTH{1'b0}};
                    end
                end
            endcase 
        end
    end


    // factorials LUT
    always_ff @(posedge clk) begin
        if (rst) begin
            factorial[0] <= FACTORIAL_1; // 1!
            factorial[1] <= FACTORIAL_2; // 2!
            factorial[2] <= FACTORIAL_3; // 3!
            factorial[3] <= FACTORIAL_4; // 4!
            factorial[4] <= FACTORIAL_5; // 5!
            factorial[5] <= FACTORIAL_6; // 6!
            factorial[6] <= FACTORIAL_7; // 7!
            factorial[7] <= FACTORIAL_8; // 8!
            factorial[8] <= FACTORIAL_9; // 9!
            factorial[9] <= FACTORIAL_10; // 10!
        end 
    end

    generate 
        if (NUM_DIVIDES > 0) begin
            genvar i;
            for (i=0; i<NUM_DIVIDES; i++) begin: DIV

                pow #(
                    .POW            (i+2),
                    .DATA_WIDTH     (DATA_WIDTH),
                    .LPM_PIPE_WIDTH (LPM_PIPE_WIDTH),
                    .FRACTION       (FRACTION)
                ) power_of (
                    .clk            (clk),
                    .rst            (rst),

                    .pow_ready_in   (pow_ready_in[i]),
                    .pow_valid_in   (1'b1),
                    .pow_data_in    (exp_data_in_reg),
                    
                    .pow_ready_out  (pow_ready_out[i]),
                    .pow_valid_out  (pow_valid_out[i]),
                    .pow_data_out   (pow_data_out[i])
                );

                divide #(
                    .DATA_WIDTH (DATA_WIDTH),
                    .LPM_PIPE_WIDTH (LPM_PIPE_WIDTH)
                ) divider (
                    .clk      (clk),
                    .rst      (rst),

                    .divide_ready_in (pow_ready_out[i]),
                    .divide_valid_in (pow_valid_out[i]),
                    .divide_numer_in (pow_data_out[i]),
                    .divide_denom_in (factorial[i+1]),

                    .divide_ready_out (exp_ready_out),
                    .divide_valid_out (div_valid_out[i]),
                    .divide_quotient_out (div_data_out[i]),
                    .divide_remain_out () // unconnected
                );
            end
        end



        if (NUM_DIVIDES > 1) begin
            genvar j;
            for (j=1; j<NUM_DIVIDES; j++) begin: SUM_REDUCE
                always_ff @(posedge clk) begin
                    if (j==1) begin 
                        div_sum[j] <= div_data_out[j-1] + div_data_out[j];
                    end else begin
                        div_sum[j] <= div_sum[j-1] + div_data_out[j];
                    end    
                end
            end
        end else if (NUM_DIVIDES > 0) begin
            assign div_sum[NUM_DIVIDES-1] = div_data_out[0];
        end else begin
            assign div_sum[NUM_DIVIDES-1] = {DATA_WIDTH{1'b0}};
        end
    endgenerate

    assign exp_data_out = {1'b1, {FRACTION{1'b0}}} + exp_data_in_reg + div_sum[NUM_DIVIDES-1];


endmodule