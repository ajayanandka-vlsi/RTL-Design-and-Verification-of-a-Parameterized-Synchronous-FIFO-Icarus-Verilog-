// Code your testbench here
// or browse Examples
`timescale 1ns/1ps
module tb_sync_fifo;
    parameter DEPTH = 16;
    parameter DATA_WIDTH = 8;
    parameter AF_THRESH = 14;
    parameter AE_THRESH = 2;

    reg clk;
    reg rst;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire full;
    wire empty;
    wire almost_full;
    wire almost_empty;

    integer i;
    integer errors;

    sync_fifo #(DEPTH, DATA_WIDTH, AF_THRESH, AE_THRESH) dut (
        .clk(clk),
        .rst(rst),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty),
        .almost_full(almost_full),
        .almost_empty(almost_empty)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("fifo_adv.vcd");
        $dumpvars(0, tb_sync_fifo);
        
        clk = 0;
        rst = 1;
        wr_en = 0;
        rd_en = 0;
        data_in = 0;
        errors = 0;

        #15 rst = 0;

        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            wr_en = 1;
            data_in = 8'h10 + i;
        end
        @(negedge clk);
        wr_en = 0;

        @(negedge clk);
        if (full !== 1'b1) errors = errors + 1;
        wr_en = 1;
        data_in = 8'hFF; 
        @(negedge clk);
        wr_en = 0;

        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            rd_en = 1;
            @(posedge clk);
            #1; 
            if (data_out !== (8'h10 + i)) begin
                errors = errors + 1;
            end
        end
        @(negedge clk);
        rd_en = 0;

        @(negedge clk);
        if (empty !== 1'b1) errors = errors + 1;
        rd_en = 1;
        @(negedge clk);
        rd_en = 0;

        if (errors == 0)
            $display("\n===================================\nSTATUS: SIMULATION PASS\n===================================\n");
        else
            $display("\n===================================\nSTATUS: SIMULATION FAIL (%0d ERRORS)\n===================================\n", errors);

        #20 $finish;
    end
endmodule