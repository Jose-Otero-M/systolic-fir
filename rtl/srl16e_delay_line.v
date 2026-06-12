module srl16e_delay_line #(
    parameter integer DATA_W = 16,
    parameter [3:0]   DELAY_SEL = 4'd15
)(
    input  wire              clk,
    input  wire              ce,
    input  wire [DATA_W-1:0] din,
    output wire [DATA_W-1:0] dout
);

    genvar bit_idx;

    generate
        for (bit_idx = 0; bit_idx < DATA_W; bit_idx = bit_idx + 1) begin : gen_srl16e

            SRL16E #(
                .INIT(16'h0000)
            ) u_srl16e (
                .Q   (dout[bit_idx]),
                .A0  (DELAY_SEL[0]),
                .A1  (DELAY_SEL[1]),
                .A2  (DELAY_SEL[2]),
                .A3  (DELAY_SEL[3]),
                .CE  (ce),
                .CLK (clk),
                .D   (din[bit_idx])
            );

        end
    endgenerate

endmodule