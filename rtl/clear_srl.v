module clear_srl #(
    parameter integer SRL_W     = 16,
    parameter integer SRL_DEPTH = 33
)(
    input wire clk,
    input wire rst,
    input wire en,
    input wire signed [SRL_W-1:0] x_in,
    input wire x_in_valid,

    output reg signed [SRL_W-1:0] x_in_or_zeros,
    output reg flushing_srl,
    output reg ce_srl,
    output reg ce_dsp
);

    initial begin
        if (SRL_DEPTH <= 0) begin
            $display("Error: SRL_DEPTH must be greater than zero.");
            $finish;
        end
    end

    localparam integer COUNTER_W = (SRL_DEPTH <= 1) ? 1 : $clog2(SRL_DEPTH + 1);
    reg [COUNTER_W-1:0] counter_srl_flushed = {COUNTER_W{1'b0}};
    reg srl_needs_flush = 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            counter_srl_flushed <= {COUNTER_W{1'b0}};
            srl_needs_flush <= 1'b1;

            x_in_or_zeros <= {(SRL_W){1'b0}};
            ce_srl <= 1'b0;
            ce_dsp <= 1'b0;
            flushing_srl <= 1'b1;
        end

        else if(srl_needs_flush) begin
            x_in_or_zeros <= {(SRL_W){1'b0}};
            ce_srl <= 1'b1;
            ce_dsp <= 1'b0;
            flushing_srl <= 1'b1;

            if(counter_srl_flushed == SRL_DEPTH-1) begin
                counter_srl_flushed <= {COUNTER_W{1'b0}};
                srl_needs_flush <= 1'b0;
            end
            else begin
                counter_srl_flushed <= counter_srl_flushed + 1'b1;
                srl_needs_flush <= 1'b1;
            end
        end
        else begin
            x_in_or_zeros <= x_in;
            ce_srl <= en & x_in_valid;
            ce_dsp <= en & x_in_valid;
            flushing_srl <= 1'b0;
            counter_srl_flushed <= {COUNTER_W{1'b0}};
            srl_needs_flush <= 1'b0;
        end
    end

endmodule