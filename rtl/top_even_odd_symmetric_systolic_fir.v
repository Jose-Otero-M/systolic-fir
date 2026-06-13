module top_even_odd_symmetric_systolic_fir #(
    parameter integer NTAPS            = 33, // Number of FIR taps
    parameter integer XW               = 16, // Input data width
    parameter integer CW               = 16, // Coefficient width (e.g., Q1.15)
    parameter integer YW               = 16, // Output data width
    parameter integer GUARD_BITS       =  1, // Number of guard bits
    parameter integer ACCW             = XW + CW + $clog2(NTAPS) + GUARD_BITS, // Accumulator width with guard bits
    parameter integer SHIFT            = 15, // Right shift after MAC (Q1.15 -> integer)

    parameter integer CHECK_SYMMETRY   =  1, // Whether to check for symmetry in coefficients  
    parameter integer USE_SYMMETRY     =  1, // Whether to use symmetric coefficients optimization
    parameter integer STRICT_SYMMETRY  =  1, 

    parameter integer USE_SRL16E       =  1,

    parameter integer SATURATE_OUTPUT  =  1,
    parameter integer ROUND_TO_NEAREST =  1, // Whether to round to nearest after shifting
    parameter         COEF_FILE        = "rrc_taps_q15_energy.mem" // Coefficient file
    )
    
    (
    input wire clk, // Clock
    input wire rst, // Synchronous reset
    input wire  en, // Clock enable for processing samples
    
    input wire signed [XW-1:0] x_in,        // Input sample
    input wire                 data_valid,  // Input sample valid strobe
    
    output wire signed [YW-1:0] y_out,      // Output sample
    output wire                 y_out_valid // Output valid strobe
    );
    
    
    //(* rom_style = "block" *) // AMD synthesis directive (use BRAM)
    (* rom_style = "distributed" *) // AMD synthesis directive (use LUTs)
    reg signed [CW-1:0] coef_array [0:NTAPS-1]; 

    integer i;
    integer symmetry_errors;
    localparam integer PW = XW + CW; // Product width before accumulation


    /*
    * Parameter and coefficient initialization.
    *
    * These cheks are intended maily for simulation.
    */
    initial begin
        if (NTAPS < 1) begin
            $display("Error: NTAPS must be at least 1. Given: %0d", NTAPS);
            $finish;
        end

        if (XW < 2 || CW < 2 || YW < 2) begin
            $display("Error: Word widths must be at least 2 bits. Given: XW=%0d, CW=%0d, YW=%0d", XW, CW, YW);
            $finish;
        end

        if (ACCW < PW) begin
            $display("Warning: ACCW may be too small to avoid overflow. Recommended ACCW >= %0d. Given: %0d", PW + $clog2(NTAPS) + GUARD_BITS, ACCW);
            $finish;
        end

        if (SHIFT < 0) begin
            $display("Error: SHIFT must be non-negative. Given: %0d", SHIFT);
            $finish;
        end

        if (SHIFT >= ACCW) begin
            $display("Error: SHIFT must be less than ACCW to avoid shifting out all bits. Given: SHIFT=%0d, ACCW=%0d", SHIFT, ACCW);
            $finish;
        end

        for (i = 0; i < NTAPS; i = i + 1) begin
            coef_array[i] = {CW{1'b0}}; // Default to zero
        end

        // Load coefficients from file
        $readmemh(COEF_FILE, coef_array);

        // Check for symmetry if enabled
        if ((USE_SYMMETRY != 0) && (CHECK_SYMMETRY != 0)) begin
            symmetry_errors = 0;
            for (i = 0; i < NTAPS/2; i = i + 1) begin
                if (coef_array[i] !== coef_array[NTAPS-1-i]) begin
                    $display("WARNING: Symmetry error! coef[%0d] = %h does not match coef[%0d] = %h", i, coef_array[i], NTAPS-1-i, coef_array[NTAPS-1-i]);
                    symmetry_errors = symmetry_errors + 1;
                end
            end
            if (symmetry_errors > 0) begin
                $display("Total symmetry errors: %0d out of %0d pairs", symmetry_errors, NTAPS/2);
            end else begin
                $display("Coefficient symmetry check passed. All %0d pairs are symmetric.", NTAPS/2);
            end

            if ((symmetry_errors != 0) && (STRICT_SYMMETRY != 0)) begin
                $display("ERROR: Coefficient symmetry check failed");
                $display("       Disable STRICT_SYMMETRY or provide symmetryc coeficients");
                $finish;
            end
        end
    end

    localparam integer PAIRS       = NTAPS / 2;
    localparam integer HAS_CENTER  = NTAPS % 2;
    localparam integer DSP_STAGES  = PAIRS + HAS_CENTER;
    localparam integer CENTER_IDX  = PAIRS;

    wire ce;
    assign ce = en & data_valid;

    // Duplicate tap delay: z^-NTAPS
    wire signed [XW-1:0] x_duplicate;

    srl16e_delay_line #(
        .DATA_W(XW),
        .DELAY (NTAPS)
    ) u_duplicate_delay (
        .clk  (clk),
        .ce   (ce),
        .din  (x_in),
        .dout (x_duplicate)
    );

    // Horizontal systolic sample chain.
    // One entry per symmetric pair stage.
    wire signed [XW-1:0] x_chain [0:PAIRS];

    // Accumulator cascade.
    // One accumulator node per DSP stage plus initial zero.
    wire signed [ACCW-1:0] acc_chain [0:DSP_STAGES];

    assign x_chain[0]   = x_in;
    assign acc_chain[0] = {ACCW{1'b0}};

    genvar j;

    generate

        /*
        * Symmetric pair stages:
        *
        * Even NTAPS = 8:
        *   j = 0,1,2,3
        *
        * Odd NTAPS = 9:
        *   j = 0,1,2,3
        *
        * Each stage implements:
        *
        *   h[j] * (x_a + x_b)
        *
        */
        for (j = 0; j < PAIRS; j = j + 1) begin : gen_symmetric_pair_stage

            dsp_symmetric_systolic_stage #(
                .XW   (XW),
                .CW   (CW),
                .ACCW (ACCW)
            ) u_dsp_pair (
                .clk       (clk),
                .rst       (rst),
                .ce        (ce),

                .x_forward_in  (x_chain[j]),
                .x_duplicate_in(x_duplicate),
                .x_forward_out (x_chain[j+1]),

                .coef_in   (coef_array[j]),

                .acc_in    (acc_chain[j]),
                .acc_out   (acc_chain[j+1])
            );

        end

        /*
        * Center tap stage.
        *
        * Only exists when NTAPS is odd.
        *
        * Example:
        *
        * NTAPS = 9:
        *   center coefficient = h4
        *
        * NTAPS = 33:
        *   center coefficient = h16
        *
        */
        if (HAS_CENTER != 0) begin : gen_center_stage

            dsp_center_systolic_stage #(
                .XW   (XW),
                .CW   (CW),
                .ACCW (ACCW)
            ) u_dsp_center (
                .clk     (clk),
                .rst     (rst),
                .ce      (ce),

                .x_in    (x_duplicate),
                .coef_in (coef_array[CENTER_IDX]),

                .acc_in  (acc_chain[PAIRS]),
                .acc_out (acc_chain[PAIRS+1])
            );

        end

    endgenerate

    wire signed [ACCW-1:0] acc_final;
    assign acc_final = acc_chain[DSP_STAGES];


endmodule