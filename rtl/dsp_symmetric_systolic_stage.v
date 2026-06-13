module dsp_symmetric_systolic_stage #(
    parameter integer XW         = 16,
    parameter integer CW         = 16,
    parameter integer NTAPS      = 8,
    parameter integer GUARD_BITS = 1,
    parameter integer ACCW       = XW + CW + $clog2(NTAPS) + GUARD_BITS
)(
    input  wire clk,
    input  wire rst,
    input  wire en,

    input  wire signed [XW-1:0]   x_a,
    input  wire signed [XW-1:0]   x_b,
    input  wire signed [CW-1:0]   coef_in,
    input  wire signed [ACCW-1:0] mac_in,

    output reg signed [ACCW-1:0]  mac_out
);

    localparam integer PREADD_W = XW + 1;
    localparam integer PROD_W   = PREADD_W + CW;

    reg signed [PREADD_W-1:0] preadd_reg;
    reg signed [CW-1:0]       coef_reg;
    reg signed [PROD_W-1:0]   product_reg;

    wire signed [ACCW-1:0] product_ext;

    assign product_ext = {{(ACCW-PROD_W){product_reg[PROD_W-1]}}, product_reg};

    always @(posedge clk) begin
        if (rst) begin
            preadd_reg  <= {PREADD_W{1'b0}};
            coef_reg    <= {CW{1'b0}};
            product_reg <= {PROD_W{1'b0}};
            mac_out     <= {ACCW{1'b0}};
        end else if (en) begin
            preadd_reg  <= {x_a[XW-1], x_a} + {x_b[XW-1], x_b};
            coef_reg    <= coef_in;
            product_reg <= preadd_reg * coef_reg;
            mac_out     <= mac_in + product_ext;
        end
    end

endmodule