module top_systolic_fir #(
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
    input wire                 x_in_valid,  // Input sample valid strobe
    
    output wire signed [YW-1:0] y_out,      // Output sample
    output wire                 y_out_valid // Output valid strobe
);


    wire signed [ACCW-1:0] acc_final;
    wire acc_final_valid;

    even_odd_symmetric_systolic_structure #(
        .NTAPS(NTAPS),
        .XW(XW),
        .CW(CW),
        .YW(YW),
        .GUARD_BITS(GUARD_BITS),
        .ACCW(ACCW),
        .CHECK_SYMMETRY(CHECK_SYMMETRY),
        .USE_SYMMETRY(USE_SYMMETRY),
        .STRICT_SYMMETRY(STRICT_SYMMETRY),
        .USE_SRL16E(USE_SRL16E),
        .COEF_FILE(COEF_FILE)
    ) u_systolic_structure(
        .clk(clk),
        .rst(rst),
        .en(en),
        .x_in(x_in),
        .x_in_valid(x_in_valid),
        .acc_final(acc_final),
        .acc_final_valid(acc_final_valid)
    );

    round_shift #(
        .XW(XW),
        .YW(YW),
        .ACCW(ACCW),
        .SHIFT(SHIFT),
        .SATURATE_OUTPUT(SATURATE_OUTPUT),
        .ROUND_TO_NEAREST(ROUND_TO_NEAREST)
    ) u_round_shift(
        .clk(clk),
        .rst(rst),
        .en(en),
        .acc_final(acc_final),
        .acc_final_valid(acc_final_valid),
        .y_out(y_out),
        .y_out_valid(y_out_valid)
    );

endmodule