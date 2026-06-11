module top_systolic_fir #(
    parameter integer NTAPS      = 33,  // Number of FIR taps
    parameter integer XW         = 16,  // Input data width
    parameter integer CW         = 16,  // Coefficient width (e.g., Q1.15)
    parameter integer YW         = 16,  // Output data width
    parameter integer GUARD_BITS =  1,  // Number of guard bits
    parameter integer ACCW       = XW + CW + $clog2(NTAPS) + GUARD_BITS, // Accumulator width with guard bits
    parameter integer SHIFT      = 15, // Right shift after MAC (Q1.15 -> integer)
    parameter integer USE_SYMMETRY = 1, // Whether to use symmetric coefficients optimization
    parameter integer CHECK_SYMMETRY = 1, // Whether to check for symmetry in coefficients  
    parameter integer ROUND_TO_NEAREST = 1, // Whether to round to nearest after shifting
    parameter         COEF_FILE = "rrc_taps_q15_energy.mem" // Coefficient file
    )
    
    (
    input wire clk, // clock
    input wire rst, // synchronous reset
    input wire ce,  // clock enable for processing samples
    
    input wire signed [XW-1:0] x_in, // input sample
    input wire data_valid,           // input sample valid strobe
    
    output wire signed [YW-1:0] y_out, // output sample
    output wire y_out_valid            // output valid strobe
    );
    
    
    //(* rom_style = "block" *)
    (* rom_style = "distributed" *)
    reg signed [CW-1:0] coef_array [0:NTAPS-1];

    integer i;
    integer symmetric_errors;
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
            $display("Error: Word widths must be at least 2 bits. 
            Given: XW=%0d, CW=%0d, YW=%0d", XW, CW, YW);
            $finish;
        end

        if (ACCW < PW) begin
            $display("Warning: ACCW may be too small to avoid overflow. 
            Recommended ACCW >= %0d. Given: %0d", PW + $clog2(NTAPS) + GUARD_BITS, ACCW);
        end

        if (SHIFT < 0) begin
            $display("Error: SHIFT must be non-negative. Given: %0d", SHIFT);
            $finish;
        end

        if (SHIFT >= ACCW) begin
            $display("Error: SHIFT must be less than ACCW to avoid shifting out all bits. 
            Given: SHIFT=%0d, ACCW=%0d", SHIFT, ACCW);
            $finish;
        end

        for (i = 0; i < NTAPS; i = i + 1) begin
            coef_array[i] = {CW{1'b0}}; // Default to zero
        end

        // Load coefficients from file
        $readmemh(COEF_FILE, coef_array);

        // Check for symmetry if enabled
        if ((USE_SYMMETRY != 0) && (CHECK_SYMMETRY != 0)) begin
            symmetric_errors = 0;
            for (i = 0; i < NTAPS/2; i = i + 1) begin
                if (coef_array[i] !== coef_array[NTAPS-1-i]) begin
                    $display("WARNING: Symmetry error! coef[%0d] = %h does not match coef[%0d] = %h",
                             i, coef_array[i], NTAPS-1-i, coef_array[NTAPS-1-i]);
                    symmetric_errors = symmetric_errors + 1;
                end
            end
            if (symmetric_errors > 0) begin
                $display("Total symmetry errors: %0d out of %0d pairs", symmetric_errors, NTAPS/2);
            end else begin
                $display("Coefficient symmetry check passed. All %0d pairs are symmetric.", NTAPS/2);
            end
        end
    end

    

end module