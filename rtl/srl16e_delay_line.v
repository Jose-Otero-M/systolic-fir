module srl16e_delay_line #(
    parameter integer DATA_W = 16,
    parameter integer DELAY  = 33
    )
    (
    input  wire              clk,
    input  wire              ce,
    input  wire [DATA_W-1:0] din,
    output wire [DATA_W-1:0] dout
    );
    
    // Constant function for ceiling division.
    function integer ceil_div
        input integer numerator;
        input integer denominator;

        begin
            if ((numerator <= 0) || (denominator <= 0))
                ceil_div = 0;
            else if((numerator % denominator) == 0)
                ceil_div = numerator / denominator;
            else
                ceil_div = (numerator / denominator) + 1;
        end
    endfunction


    // Constant function to calculate the delay assigned to each SRL16E stage.
    function integer get_stage_delay;
        input integer stage_idx;
        integer remaining_delay;
        begin
            remaining_delay = DELAY - (stage_idx * 16);

            if (remaining_delay >= 16)
                get_stage_delay = 16;
            else if (remaining_delay > 0)
                get_stage_delay = remaining_delay;
            else
                get_stage_delay = 0;
        end
    endfunction

    localparam integer MAX_SRL_DEPTH = 16;
    localparam integer NUM_SRL   = ceil_div(DELAY, MAX_SRL_DEPTH);

    wire [DATA_W*(NUM_SRL+1)-1:0] chain;

    assign chain[DATA_W-1:0] = din;
    assign dout = chain[DATA_W*NUM_SRL +: DATA_W];

    genvar stage_idx;
    genvar bit_idx;

    generate
        for (stage_idx = 0; stage_idx < NUM_SRL; stage_idx = stage_idx + 1) begin : gen_srl_stage

            localparam integer STAGE_DELAY = get_stage_delay(stage_idx);
            localparam [3:0]   STAGE_ADDR  = STAGE_DELAY - 1;

            for (bit_idx = 0; bit_idx < DATA_W; bit_idx = bit_idx + 1) begin : gen_srl_bit

                SRL16E #(
                    .INIT(16'h0000)
                ) u_srl16e (
                    .Q   (chain[DATA_W*(stage_idx+1) + bit_idx]),
                    .A0  (STAGE_ADDR[0]),
                    .A1  (STAGE_ADDR[1]),
                    .A2  (STAGE_ADDR[2]),
                    .A3  (STAGE_ADDR[3]),
                    .CE  (ce),
                    .CLK (clk),
                    .D   (chain[DATA_W*stage_idx + bit_idx])
                );

            end
        end
    endgenerate

/*    
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
*/
endmodule