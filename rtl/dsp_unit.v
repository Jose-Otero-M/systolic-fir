module dsp_unit #(
    parameter integer NTAPS      = 33,
    parameter integer XW         = 16, // Input width
    parameter integer CW         = 16, // Coefficient width
    parameter integer GUARD_BITS =  1, // Number of guard bits
    parameter integer ACCW       = XW + CW + $clog2(NTAPS) + GUARD_BITS // Accumulator width with guard bits
    )

    (
    input wire clk,
    input wire rst,
    input wire en,
    input wire signed [XW-1:0] x_delayed, // Delayed input sample for z-2
    input wire signed [XW-1:0] x_delayed_srl, // Delayed and shifted input sample for SRL z-1
    input wire signed [CW-1:0] coef_in, // Coefficient input for the current stage
    input wire signed [ACCW-1:0] mac_in, // Accumulator input from previous stage
    output wire signed [ACCW-1:0] mac_out_registered
    );
      
    localparam integer PREADDER_WIDTH_IN = XW;
    localparam integer PREADDER_WIDTH_OUT = XW + 1;

    wire [2*XW-1:0] x_z2_flattened; // Flattened delay line output for z-2
    reg signed [XW-1:0] x_z1; // Delayed input sample x_delayed by z-1
    reg signed [XW-1:0] x_z2; // Delayed input sample x_delayed by z-2

    wire signed [XW-1:0] srl_z1; // Shifted and delayed input sample for SRL z-1

    reg signed [PREADDER_WIDTH_IN-1:0] pre_adder_in_x;
    reg signed [PREADDER_WIDTH_IN-1:0] pre_adder_in_x_srl;
    reg signed  [PREADDER_WIDTH_OUT-1:0] pre_adder_out;

    wire signed [XW:0] pre_adder_out_extended_registered; // Pre-adder output extended to accumulator width
    wire signed [CW:0] extended_coef_delayed_z1; // Delayed coefficient for z-1
    
    reg signed [$bits(pre_adder_out_extended_registered) + 
                $bits(extended_coef_delayed_z1)-1:0] product; // Product of pre-adder output and coefficient
    
    wire signed [$bits(product)-1:0] product_registered; // Output of the MAC operation
    reg signed [ACCW-1:0] product_registered_extended; // Product registered and extended to accumulator width for MAC input
    reg signed [ACCW-1:0] mac_result; // Result of the MAC operation before registering

/*
    initial begin
        if (XW <= 0) begin
            $error("Invalid XW=%0d. XW must be > 0.", XW);
            $fatal;
        end

        if (ACCW <= 0) begin
            $error("Invalid ACCW=%0d. ACCW must be > 0.", ACCW);
            $fatal;
        end
    end
*/
    delay_line_M_words_N_bits #(.M_STAGES(2), .N_BITS(XW)
    ) u_delay_z2(
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in(x_delayed),
        .data_out_flat(x_z2_flattened) // adder_in_x is the delayed x input
    );

    delay_line_M_words_N_bits #(.M_STAGES(1), .N_BITS(XW)
    ) u_delay_z1(
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in(x_delayed_srl),
        .data_out_flat(srl_z1) // adder_in_x_srl is the delayed and shifted x input
    );

    // Unflatten the delay line output
    always @(*) begin
        x_z1 = x_z2_flattened[XW-1:0];    // z-1
        x_z2 = x_z2_flattened[2*XW-1:XW]; // z-2
    end

    always @(*) begin
        pre_adder_in_x = x_z2;
        pre_adder_in_x_srl = srl_z1;
        pre_adder_out = pre_adder_in_x + pre_adder_in_x_srl; // Pre-adder output
    end

    delay_line_M_words_N_bits #(.M_STAGES(1), .N_BITS(XW+1)
    ) u_z1_out_pre_adder(
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in(pre_adder_out),
        .data_out_flat(pre_adder_out_extended_registered) // pre_adder_out_extended is the delayed pre-adder output registered
    );

    delay_line_M_words_N_bits #(.M_STAGES(1), .N_BITS(CW+1)
    ) u_coeff_z1_delayed(
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in({ {1{coef_in[CW-1]}}, coef_in }), // Sign-extend the coefficient input to match the pre-adder output width
        .data_out_flat(extended_coef_delayed_z1) // extended_coef_delayed_z1 is the delayed coefficient input
    );

    always @(*) begin
        product = pre_adder_out_extended_registered * extended_coef_delayed_z1; // Multiply pre-adder output by delayed coefficient
    end

    delay_line_M_words_N_bits #(.M_STAGES(1), .N_BITS($bits(product))
    ) u_z1_out_product(
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in(product), // Product of pre-adder output and delayed coefficient
        .data_out_flat(product_registered) // Registered product output for use in the MAC operation
    );

    always @(*) begin
        product_registered_extended = 
        {{(ACCW-$bits(product_registered)){product_registered[$bits(product_registered)-1]}}, product_registered}; // Sign-extend the registered product to match the accumulator width

        mac_result = mac_in + product_registered_extended; // Perform the MAC operation by adding the registered product to the accumulator input
    end

    delay_line_M_words_N_bits #(.M_STAGES(1), .N_BITS($bits(mac_result))
    ) u_mac_out(
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in(mac_result), // Result of the MAC operation
        .data_out_flat(mac_out_registered) // Registered MAC output
    );




endmodule