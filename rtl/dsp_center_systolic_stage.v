module dsp_center_systolic_stage #(
    parameter integer XW   = 16,
    parameter integer CW   = 16,
    parameter integer ACCW = 40
)(
    input  wire clk,
    input  wire rst,
    input  wire ce,

    input  wire signed [XW-1:0]   x_in,
    input  wire x_valid_in,

    input  wire signed [CW-1:0]   coef_in,

    input  wire signed [ACCW-1:0] acc_in,
    output reg  signed [ACCW-1:0] acc_out,

    input  wire acc_valid_in,
    output reg  acc_valid_out
);

    localparam integer PROD_W = XW + CW;

    reg signed [XW-1:0]     x_reg;
    reg signed [CW-1:0]     coef_reg;
    reg signed [PROD_W-1:0] product_reg;

    wire signed [ACCW-1:0] product_ext;

    assign product_ext = {{(ACCW-PROD_W){product_reg[PROD_W-1]}}, product_reg};

    always @(posedge clk) begin
        if (rst) begin
            x_reg       <= {XW{1'b0}};
            coef_reg    <= {CW{1'b0}};
            product_reg <= {PROD_W{1'b0}};

            x_valid_reg       <= 1'b0;
            product_valid_reg <= 1'b0;

            acc_out       <= {ACCW{1'b0}};
            acc_valid_out <= 1'b0;
        end else if (ce) begin
            x_reg       <= x_in;
            coef_reg    <= coef_in;
            product_reg <= x_reg * coef_reg;

            x_valid_reg       <= x_valid_in;
            product_valid_reg <= x_valid_reg;

            acc_out       <= acc_in + product_ext;
            acc_valid_out <= acc_valid_in & product_valid_reg;
        end
    end

endmodule