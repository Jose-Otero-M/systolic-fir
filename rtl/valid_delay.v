module valid_delay #(
    parameter integer DELAY = 1
)(
    input  wire clk,
    input  wire rst,
    input  wire ce,
    input  wire din,
    output wire dout
);

generate
    if (DELAY == 0) begin : gen_no_delay
        // Caso de retardo 0
        assign dout = din;

    end else if (DELAY == 1) begin : gen_delay_1
        // Caso de retardo 1 (evita el índice negativo)
        reg sr;
        
        always @(posedge clk) begin
            if (rst) begin
                sr <= 1'b0;
            end else if (ce) begin
                sr <= din;
            end
        end
        
        assign dout = sr;

    end else begin : gen_delay_n
        // Caso general para retardo >= 2
        reg [DELAY-1:0] sr;

        always @(posedge clk) begin
            if (rst) begin
                sr <= {DELAY{1'b0}};
            end else if (ce) begin
                sr <= {sr[DELAY-2:0], din};
            end
        end

        assign dout = sr[DELAY-1];
    end
endgenerate

endmodule