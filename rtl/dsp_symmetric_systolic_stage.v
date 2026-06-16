module dsp_symmetric_systolic_stage #(
    parameter integer XW   = 16,
    parameter integer CW   = 16,
    parameter integer ACCW = 40
)(
    input  wire clk,
    input  wire rst,
    input  wire ce,

    input  wire signed [XW-1:0] x_forward_in,
    input  wire signed [XW-1:0] x_duplicate_in,
    output wire signed [XW-1:0] x_forward_out,

    input  wire x_forward_valid_in,
    input  wire x_duplicate_valid_in,
    output wire x_forward_valid_out,

    input  wire signed [CW-1:0] coef_in,

    input  wire signed [ACCW-1:0] acc_in,
    output reg  signed [ACCW-1:0] acc_out
);

    localparam integer PREADD_W = XW + 1;
    localparam integer PROD_W   = PREADD_W + CW;

    reg signed [XW-1:0] x_fwd_d1;
    reg signed [XW-1:0] x_fwd_d2;
    reg signed [XW-1:0] x_dup_d1;

    reg x_fwd_valid_d1;
    reg x_fwd_valid_d2;
    reg x_dup_valid_d1;

    reg signed [PREADD_W-1:0] preadd_reg;
    reg signed [CW-1:0]       coef_reg;
    reg signed [PROD_W-1:0]   product_reg;

    reg preadd_valid_reg;
    reg product_valid_reg;

    wire signed [ACCW-1:0] product_ext;

    assign x_forward_out = x_fwd_d2;
    assign x_forward_valid_out = x_fwd_valid_d2;

    assign product_ext = {{(ACCW-PROD_W){product_reg[PROD_W-1]}}, product_reg};

    always @(posedge clk) begin
        if (rst) begin
            x_fwd_d1    <= {XW{1'b0}};
            x_fwd_d2    <= {XW{1'b0}};
            x_dup_d1    <= {XW{1'b0}};

            x_fwd_valid_d1    <= 1'b0;
            x_fwd_valid_d2    <= 1'b0;
            x_dup_valid_d1    <= 1'b0;

            preadd_reg  <= {PREADD_W{1'b0}};
            coef_reg    <= {CW{1'b0}};
            product_reg <= {PROD_W{1'b0}};

            preadd_valid_reg  <= 1'b0;
            product_valid_reg <= 1'b0;

            acc_out       <= {ACCW{1'b0}};
            acc_valid_out <= 1'b0;

        end else if (ce) begin
            // Horizontal systolic sample delay: z^-2
            x_fwd_d1 <= x_forward_in;
            x_fwd_d2 <= x_fwd_d1;

            x_fwd_valid_d1 <= x_forward_valid_in;
            x_fwd_valid_d2 <= x_fwd_valid_d1;


            // Duplicate path local delay: z^-1
            x_dup_d1 <= x_duplicate_in;
            x_dup_valid_d1 <= x_duplicate_valid_in;

            // Pre-adder
            preadd_reg <= {x_fwd_d2[XW-1], x_fwd_d2} +
                          {x_dup_d1[XW-1], x_dup_d1};

            preadd_valid_reg <= x_fwd_valid_d2 & x_dup_valid_d1;

            // Coefficient pipeline
            coef_reg <= coef_in;

            // Multiplier
            product_reg <= preadd_reg * coef_reg;

            product_valid_reg <= preadd_valid_reg;

            // Accumulator cascade
            acc_out <= acc_in + product_ext;

            acc_valid_out <= acc_valid_in & product_valid_reg;
        end
    end

endmodule