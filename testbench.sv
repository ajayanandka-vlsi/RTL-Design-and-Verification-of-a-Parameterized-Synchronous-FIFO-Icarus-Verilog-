`timescale 1ns/1ps
module tb_sync_fifo;
    reg clk;
    initial clk = 0;
    always #5 clk = ~clk;

    wire        done16, done10;
    wire [31:0] err16,  err10;

    fifo_check #(.DEPTH(16), .AF_THRESH(14), .AE_THRESH(2), .SEED(11)) chk16 (.clk(clk), .done(done16), .errors(err16));
    fifo_check #(.DEPTH(10), .AF_THRESH(8),  .AE_THRESH(2), .SEED(23)) chk10 (.clk(clk), .done(done10), .errors(err10));

    initial begin
        $dumpfile("fifo_adv.vcd");
        $dumpvars(0, tb_sync_fifo);
        wait (done16 && done10);
        #20;
        $display("DEPTH=16 errors: %0d   DEPTH=10 errors: %0d", err16, err10);
        if (err16 == 0 && err10 == 0)
            $display("\n===================================\nSTATUS: SIMULATION PASS\n===================================\n");
        else
            $display("\n===================================\nSTATUS: SIMULATION FAIL (%0d ERRORS)\n===================================\n", err16 + err10);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("STATUS: SIMULATION FAIL (timeout)");
        $finish;
    end
endmodule

module fifo_check #(
    parameter DEPTH      = 16,
    parameter DATA_WIDTH = 8,
    parameter AF_THRESH  = 14,
    parameter AE_THRESH  = 2,
    parameter SEED       = 1
)(
    input             clk,
    output reg        done,
    output reg [31:0] errors
);
    reg                   rst, wr_en, rd_en;
    reg  [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;
    wire                  full, empty, almost_full, almost_empty;

    sync_fifo #(DEPTH, DATA_WIDTH, AF_THRESH, AE_THRESH) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .rd_en(rd_en),
        .data_in(data_in), .data_out(data_out),
        .full(full), .empty(empty), .almost_full(almost_full), .almost_empty(almost_empty)
    );

    reg [DATA_WIDTH-1:0] q [0:65535];
    integer mwr, mrd;
    integer seed, i;
    reg                  check_data;
    reg [DATA_WIDTH-1:0] exp_data;

    integer occ_pre;
    reg     rd_ok, wr_ok;
    always @(posedge clk) begin
        if (rst) begin
            mwr = 0; mrd = 0; check_data = 0;
        end else begin
            occ_pre    = mwr - mrd;
            rd_ok      = rd_en && (occ_pre > 0);
            wr_ok      = wr_en && (occ_pre < DEPTH);
            check_data = 0;
            if (rd_ok) begin
                exp_data   = q[mrd];
                mrd        = mrd + 1;
                check_data = 1;
            end
            if (wr_ok) begin
                q[mwr] = data_in;
                mwr    = mwr + 1;
            end
        end
    end

    integer occ;
    always @(negedge clk) begin
        if (!rst) begin
            occ = mwr - mrd;
            if (full !== (occ == DEPTH) || empty !== (occ == 0) ||
                almost_full !== (occ >= AF_THRESH) || almost_empty !== (occ <= AE_THRESH)) begin
                errors = errors + 1;
                $display("ERROR D%0d @%0t flags f=%b e=%b af=%b ae=%b, model occupancy %0d",
                         DEPTH, $time, full, empty, almost_full, almost_empty, occ);
            end
            if (check_data && data_out !== exp_data) begin
                errors = errors + 1;
                $display("ERROR D%0d @%0t data_out=%h expected %h", DEPTH, $time, data_out, exp_data);
            end
        end
    end

    initial begin
        done = 0; errors = 0; seed = SEED;
        rst = 1; wr_en = 0; rd_en = 0; data_in = 0;
        mwr = 0; mrd = 0; check_data = 0;
        repeat (2) @(negedge clk);
        rst = 0;

        for (i = 0; i < DEPTH + 1; i = i + 1) begin
            @(negedge clk);
            wr_en = 1; rd_en = 0; data_in = 8'h10 + i;
        end
        @(negedge clk);
        wr_en = 0;
        if (full !== 1'b1) begin errors = errors + 1; $display("ERROR D%0d: not full after %0d writes", DEPTH, DEPTH); end

        for (i = 0; i < DEPTH + 1; i = i + 1) begin
            @(negedge clk);
            rd_en = 1; wr_en = 0;
        end
        @(negedge clk);
        rd_en = 0;
        if (empty !== 1'b1) begin errors = errors + 1; $display("ERROR D%0d: not empty after draining", DEPTH); end

        for (i = 0; i < 3000; i = i + 1) begin
            @(negedge clk);
            wr_en   = ($random(seed) % 3 != 0);
            rd_en   = ($random(seed) % 2 != 0);
            data_in = $random(seed);
        end
        @(negedge clk);
        wr_en = 0; rd_en = 0;

        while (!empty) begin
            @(negedge clk);
            rd_en = 1;
        end
        @(negedge clk);
        rd_en = 0;
        @(negedge clk);
        $display("D%0d: %0d words pushed, %0d popped", DEPTH, mwr, mrd);
        if (mwr != mrd) begin errors = errors + 1; $display("ERROR D%0d: model not empty at the end", DEPTH); end
        done = 1;
    end
endmodule
