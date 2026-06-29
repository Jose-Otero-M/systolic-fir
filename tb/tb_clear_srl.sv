`timescale 1ns/1ps

module tb_clear_srl;
    // ------------------------------------------------------------
    // Testbench parameters
    // ------------------------------------------------------------
    localparam int CLK_PERIOD_NS = 10; // 100 MHz clock
    localparam int SRL_W = 16;
    localparam int SRL_DEPTH = 33;
    localparam int N_BIT_VALID = 100;
    // ------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------
    logic clk;
    logic rst;
    logic en;
    
    logic signed [SRL_W-1:0] x_in;
    logic x_in_valid;

    logic signed [SRL_W-1:0] x_in_or_zeros;
    logic flushing_srl;
    logic ce_srl;
    logic ce_dsp;

    // ------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------ 
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // ------------------------------------------------------------
    // DUT instance
    // ------------------------------------------------------------
    clear_srl #(
        .SRL_W(SRL_W),
        .SRL_DEPTH(SRL_DEPTH)
    ) dut(
        .clk(clk),
        .rst(rst),
        .en(en),
        .x_in(x_in),
        .x_in_valid(x_in_valid),
        .x_in_or_zeros(x_in_or_zeros),
        .flushing_srl(flushing_srl),
        .ce_srl(ce_srl),
        .ce_dsp(ce_dsp)
    );

    task automatic apply_reset();
        begin
            // Reset sequence
            rst <= 1'b1;
            repeat(3) @(posedge clk);
            rst <= 1'b0;
        end
    endtask


    task automatic create_bit_valid();
        begin
            x_in_valid <= 1'b1;
            @(posedge clk);
            x_in_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    integer idx;
    // ------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------
    initial begin
        // Initial values
        rst = 1'b0;
        en  = 1'b0;
        x_in = '0;
        x_in_valid = 1'b0;


        repeat(10) @(posedge clk);
        en   <= 1'b1;
        x_in <= 16'd10;
        repeat(10) @(posedge clk);

        apply_reset();
        
        repeat(50) @(posedge clk);

        //$finish;
    end

    initial begin
        for (idx = 0; idx < N_BIT_VALID; idx = idx + 1) begin
            create_bit_valid();
        end

        $finish;
    end

endmodule