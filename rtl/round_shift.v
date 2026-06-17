module round_shift #(
    parameter integer XW = 16,
    parameter integer YW = 16,
    parameter integer ACCW = 40,
    parameter integer SHIFT = 15,
    parameter integer SATURATE_OUTPUT = 1,
    parameter integer ROUND_TO_NEAREST = 1
)
(
    input wire clk,
    input wire rst,
    input wire en,

    input wire signed [ACCW-1:0] acc_final,
    input wire                   acc_final_valid,
    
    output reg signed [YW-1:0] y_out,
    output reg                 y_out_valid
);


    initial begin
        if (YW <= 0) begin
            $display("Error: YW must be greater than zero. Given: %0d", YW);
            $finish;
        end

        if (ACCW <= 0) begin
            $display("Error: ACCW must be greater than zero. Given: %0d", ACCW);
            $finish;
        end

        if (ACCW < YW) begin
            $display("Error: ACCW should be greater than or equal to YW. Given: ACCW=%0d, YW=%0d", ACCW, YW);
            $finish;
        end

        if (SHIFT < 0) begin
            $display("Error: SHIFT must be non-negative. Given: %0d", SHIFT);
            $finish;
        end

        if (SHIFT >= ACCW) begin
            $display("Error: SHIFT must be less than ACCW. Given: SHIFT=%0d, ACCW=%0d", SHIFT, ACCW);
            $finish;
        end
    end

    reg signed [ACCW-1:0] acc_final_shifted;

    reg signed [ACCW:0] acc_final_ext; // Extended acc.
    reg signed [ACCW:0] bias_ext;      // Extended bias.
    reg signed [ACCW:0] mag_ext;       // Extended mag.
    reg signed [ACCW:0] scaled_ext;    // Extended scaled.

    always @(*) begin
        // Initial values
        acc_final_shifted = {ACCW{1'b0}};
        acc_final_ext = {acc_final[ACCW-1], acc_final}; // keeps the sign of acc_final and hold the acc_final value
        bias_ext      = {(ACCW+1){1'b0}};
        mag_ext       = {(ACCW+1){1'b0}};
        scaled_ext    = {(ACCW+1){1'b0}};

        if ((ROUND_TO_NEAREST != 0) && (SHIFT > 0)) begin   // Round half away from zero
            //acc_final_ext = {acc_final[ACCW-1], acc_final}; // keeps the sign of acc_final and hold the acc_final value

            bias_ext = {{ACCW{1'b0}}, 1'b1};      // Numeric value = 1 with width (ACCW+1)
            bias_ext = bias_ext <<< (SHIFT - 1);

            if (acc_final_ext < 0) begin
                mag_ext           = -acc_final_ext;
                scaled_ext        = (mag_ext + bias_ext) >>> SHIFT;
                acc_final_shifted = -$signed(scaled_ext[ACCW-1:0]);
            end
            else begin
                scaled_ext = (acc_final_ext + bias_ext) >>> SHIFT;
                acc_final_shifted = scaled_ext[ACCW-1:0];
            end
        end
        else if (SHIFT > 0) begin
            acc_final_shifted = acc_final >>> SHIFT;
        end
        else begin
            acc_final_shifted = acc_final;
        end
    end

    function automatic signed [YW-1:0] fit_y;
        input signed [ACCW-1:0] v;

        reg signed [ACCW-1:0] maxv_acc;
        reg signed [ACCW-1:0] minv_acc;

        begin
            maxv_acc = $signed({1'b0, {(YW-1){1'b1}}});
            minv_acc = $signed({1'b1, {(YW-1){1'b0}}});

            if (SATURATE_OUTPUT != 0) begin
                if (v > maxv_acc)
                    fit_y = maxv_acc[YW-1:0];
                else if (v < minv_acc)
                    fit_y = minv_acc[YW-1:0];
                else
                    fit_y = v[YW-1:0];
            end
            else begin
                fit_y = v[YW-1:0];
            end
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            y_out       <= {YW{1'b0}};
            y_out_valid <= 1'b0;
        end else begin
            if (en) begin
                y_out <= fit_y(acc_final_shifted);
                y_out_valid <= acc_final_valid;
            end
            else begin
                y_out_valid <= 1'b0;
            end
        end
    end

endmodule