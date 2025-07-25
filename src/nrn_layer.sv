module nrn_layer (
    clk,
    rst,

    nrn_layer_ready_in,
    nrn_layer_valid_in,
    nrn_layer_data_in,

    nrn_layer_ready_out,
    nrn_layer_valid_out,
    nrn_layer_data_out
);
    import cnn1d_pkg::*;

    parameter DATA_WIDTH        = 16;
    parameter PARAMS_INIT_FILE  = "";
    parameter NUM_NEURONS       = 32;
    parameter NEURON_INPUTS     = 32;
    parameter PIPE_WIDTH        = 4;
    parameter ACTIVATION_FUNC   = "relu";
    // position of the decimal point from the right
    parameter FRACTION          = 24;  

    parameter CLIPPED           = 0;
    parameter CLIP              = {DATA_WIDTH{1'b0}};

    parameter TANH_SAMPLES = 64;
    parameter TANH_LUT = "";
    parameter signed [DATA_WIDTH-1:0] TANH_MAX = 16'h03e0;
    parameter signed [DATA_WIDTH-1:0] TANH_MIN = 16'hfc00;
    parameter ID_MSB = 10; 
    parameter ID_LSB = 5;

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

    // column width in bits 
    localparam RAM_WIDTH = DATA_WIDTH;
    // row depth (number of rows)
    localparam RAM_DEPTH = (NEURON_INPUTS + 1) * NUM_NEURONS; // weight RAM row depth

    // width in bits of the RAM address buses
    localparam RAM_ADDRESS_W = clog2(RAM_DEPTH); 

    localparam IN_BUF_DEPTH = NEURON_INPUTS;
    localparam IN_BUF_WIDTH = DATA_WIDTH;
    localparam IN_BUF_ADDRESS_W = clog2(IN_BUF_DEPTH);
    
    localparam NEURON_INPUTS_W = clog2(NEURON_INPUTS+1);
    localparam NUM_NEURONS_W = clog2(NUM_NEURONS);

    localparam RAM_ACCESS_DELAY = 2;

    // state machine states
    typedef enum { 
        WAITING,
        RUNNING,
        FLUSH
    } state_t;


    input logic clk;
    input logic rst;

    output logic                        nrn_layer_ready_in;
    input logic                         nrn_layer_valid_in;
    input logic     [DATA_WIDTH-1:0]    nrn_layer_data_in;

    input logic                         nrn_layer_ready_out;
    output logic                        nrn_layer_valid_out;
    output logic    [DATA_WIDTH-1:0]    nrn_layer_data_out;

    state_t state, next_state;
    
    logic nrn_layer_handshake_in;    

    logic                   in_buf_address_inc;
    logic                   in_buf_clken;
    logic [IN_BUF_ADDRESS_W-1:0]    in_buf_address; 
    logic                   in_buf_address_rst;
    logic [DATA_WIDTH-1:0]  in_buf_out;
    logic                   in_buf_rden;
    logic                   in_buf_wren;

    logic ready;
    logic done;
    logic delay;

    logic [RAM_ADDRESS_W-1:0]   nrn_ram_address;
    logic                       nrn_ram_address_rst;
    logic [NEURON_INPUTS_W-1:0]   nrn_in;

    logic [RAM_ACCESS_DELAY-1:0] valid_pipe;
    logic [RAM_ACCESS_DELAY-1:0] delay_pipe;
    logic [RAM_ACCESS_DELAY-1:0] rst_pipe;

    logic [DATA_WIDTH-1:0] ram_out;

    logic mult_reduce_ready_in;
    logic mult_reduce_valid_in;
    logic signed [DATA_WIDTH-1:0] mult_reduce_dataa_in;
    logic signed [DATA_WIDTH-1:0] mult_reduce_datab_in;
    
    logic mult_reduce_ready_out;
    logic mult_reduce_valid_out;
    logic [LPM_OUT_WIDTH-1:0] mult_reduce_result_out; 

    logic afunc_ready_in;
    logic afunc_valid_in;
    logic [DATA_WIDTH-1:0] afunc_data_in;



    assign nrn_layer_ready_in = (state == WAITING);

    // clock in next_state
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= WAITING;
        end else begin
            state <= next_state;
        end
    end 

    // determine next_state
    always_comb begin
        nrn_ram_address_rst = 1'b0;

        next_state = state;
        case (state)
            WAITING: begin 
                if (in_buf_address_rst && nrn_layer_handshake_in) begin
                    next_state = RUNNING;
                end
            end
            RUNNING: begin
                nrn_ram_address_rst = (nrn_ram_address == RAM_DEPTH-1);
                if (ready && nrn_ram_address_rst) begin
                    next_state = FLUSH;
                end
            end
            FLUSH: begin
                if (ready && rst_pipe[RAM_ACCESS_DELAY-1]) begin
                    next_state = WAITING;
                end
            end
        endcase
    end

    assign in_buf_address_rst = (in_buf_address == IN_BUF_DEPTH-1);

    always_ff @(posedge clk) begin
        if (rst) begin
            in_buf_address  <= {IN_BUF_ADDRESS_W{1'b0}};
            
            nrn_ram_address <= {RAM_ADDRESS_W{1'b0}};
            nrn_in          <= {NEURON_INPUTS_W{1'b0}};
        end else begin
            case (state) 
                WAITING: begin
                    if (nrn_layer_handshake_in) begin
                        if (in_buf_address_rst) begin
                            in_buf_address <= {IN_BUF_ADDRESS_W{1'b0}};
                        end else begin
                            in_buf_address <= in_buf_address + 1'b1;
                        end
                    end 
                end
                RUNNING: begin
                    if (ready) begin
                        if (!delay) begin
                            if (in_buf_address_rst) begin
                                in_buf_address <= {IN_BUF_ADDRESS_W{1'b0}};
                            end else begin
                                in_buf_address <= in_buf_address + 1'b1;
                            end
                        end

                        if (nrn_in == NEURON_INPUTS) begin
                            nrn_in <= {NEURON_INPUTS_W{1'b0}};
                        end else begin
                            nrn_in <= nrn_in + 1'b1;
                        end

                        if (nrn_ram_address_rst) begin
                            nrn_ram_address <= {RAM_ADDRESS_W{1'b0}};
                        end else begin
                            nrn_ram_address <= nrn_ram_address + 1'b1;
                        end
                    end
                end 
            endcase
        end
    end

    assign ready = mult_reduce_ready_in | ~mult_reduce_valid_in;

    assign nrn_layer_handshake_in = nrn_layer_valid_in & nrn_layer_ready_in;
    
    assign delay = (nrn_in == NEURON_INPUTS);

    assign in_buf_wren = (state == WAITING) & nrn_layer_handshake_in;
    assign in_buf_rden = (state == RUNNING);
    assign in_buf_clken = (state == WAITING) ? 1'b1 : ready;

    // weights RAM
    sp_ram_clken #(
        .WIDTH          (IN_BUF_WIDTH),
        .DEPTH          (IN_BUF_DEPTH),
        .INIT_FILE      (""), // no init
        .ADDRESS_WIDTH  (IN_BUF_ADDRESS_W)
    ) in_buf (
        .address    (in_buf_address),
        .clken      (in_buf_clken),
        .clock      (clk),
        .data       (nrn_layer_data_in), 
        .rden       (in_buf_rden),  
        .wren       (in_buf_wren), 
        .q          (in_buf_out)
    );
 
    // valid_in pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            valid_pipe  <= {RAM_ACCESS_DELAY{1'b0}};
            delay_pipe  <= {RAM_ACCESS_DELAY{1'b0}};
            rst_pipe    <= {RAM_ACCESS_DELAY{1'b0}};
        end else begin
            if (ready) begin
                // shift the valid signal along the pipe only when ready is high
                valid_pipe  <= {valid_pipe[RAM_ACCESS_DELAY-2:0], in_buf_rden};
                delay_pipe  <= {delay_pipe[RAM_ACCESS_DELAY-2:0], delay};
                rst_pipe    <= {rst_pipe[RAM_ACCESS_DELAY-2:0], nrn_ram_address_rst};
            end
        end
    end

    // weights RAM
    sp_ram_clken #(
        .WIDTH          (RAM_WIDTH),
        .DEPTH          (RAM_DEPTH),
        .INIT_FILE      (PARAMS_INIT_FILE),
        .ADDRESS_WIDTH  (RAM_ADDRESS_W)
    ) nrn_ram (
        .address    (nrn_ram_address),
        .clken      (ready),
        .clock      (clk),
        .data       (), // unconnected (for now)
        .rden       (1'b1), // tied high (for now) 
        .wren       (1'b0), // tied low (for now)
        .q          (ram_out)
    );
    
    assign mult_reduce_valid_in = valid_pipe[RAM_ACCESS_DELAY-1];
    assign mult_reduce_dataa_in = delay_pipe[RAM_ACCESS_DELAY-1] ? {1'b1, {FRACTIONAL_BITS{1'b0}}} : in_buf_out; 
    assign mult_reduce_datab_in = ram_out;

    mult_reduce #(
        .DATA_WIDTH     (DATA_WIDTH),
        .NUM_ELEMENTS   (NEURON_INPUTS+1),
        .PIPE_WIDTH     (PIPE_WIDTH)
    ) mult_reduce (
        .clk            (clk),
        .rst            (rst),

        .mult_reduce_ready_in (mult_reduce_ready_in),
        .mult_reduce_valid_in (mult_reduce_valid_in),
        .mult_reduce_dataa_in (mult_reduce_dataa_in),
        .mult_reduce_datab_in (mult_reduce_datab_in),

        .mult_reduce_ready_out  (mult_reduce_ready_out),
        .mult_reduce_valid_out  (mult_reduce_valid_out),
        .mult_reduce_result_out (mult_reduce_result_out)
    );

    assign mult_reduce_ready_out = afunc_ready_in;
    assign afunc_valid_in = mult_reduce_valid_out;
    assign afunc_data_in = mult_reduce_result_out[LPM_OUT_MSB-:DATA_WIDTH];

    generate
        if (ACTIVATION_FUNC == "relu") begin
            relu #(
                .DATA_WIDTH     (DATA_WIDTH),
                .CLIPPED        (CLIPPED),
                .CLIP           (CLIP)
            ) relu (
                .clk            (clk),
                .rst            (rst),

                .relu_ready_in  (afunc_ready_in),
                .relu_valid_in  (afunc_valid_in),
                .relu_data_in   (afunc_data_in),
                
                .relu_ready_out (nrn_layer_ready_out),
                .relu_valid_out (nrn_layer_valid_out),
                .relu_data_out  (nrn_layer_data_out)
            );
        end else if (ACTIVATION_FUNC == "tanh") begin
            tanh #(
                .DATA_WIDTH     (DATA_WIDTH),
                .TANH_SAMPLES   (TANH_SAMPLES),
                .TANH_LUT       (TANH_LUT),
                .TANH_MAX       (TANH_MAX),
                .TANH_MIN       (TANH_MIN),
                .ID_MSB         (ID_MSB),
                .ID_LSB         (ID_LSB)
            ) tanh (
                .clk    (clk),
                .rst    (rst),

                .tanh_ready_in  (afunc_ready_in),
                .tanh_valid_in  (afunc_valid_in),
                .tanh_data_in   (afunc_data_in),

                .tanh_ready_out (nrn_layer_ready_out),
                .tanh_valid_out (nrn_layer_valid_out),
                .tanh_data_out  (nrn_layer_data_out)
            );
        end else begin
            assign afunc_ready_in = nrn_layer_ready_out;
            assign nrn_layer_valid_out = afunc_valid_in;
            assign nrn_layer_data_out  = afunc_data_in; 
        end
    endgenerate

endmodule