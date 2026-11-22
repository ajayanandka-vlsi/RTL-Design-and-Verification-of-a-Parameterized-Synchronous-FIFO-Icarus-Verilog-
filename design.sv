module sync_fifo #(
    parameter DEPTH      = 16,
    parameter DATA_WIDTH = 8,
    parameter AF_THRESH  = 14,
    parameter AE_THRESH  = 2
)(
    input                       clk,
    input                       rst,
    input                       wr_en,
    input                       rd_en,
    input      [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output                      full,
    output                      empty,
    output                      almost_full,
    output                      almost_empty
);

    localparam PW = (DEPTH > 1) ? $clog2(DEPTH) : 1;
    localparam CW = $clog2(DEPTH + 1);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PW-1:0]         wr_ptr;
    reg [PW-1:0]         rd_ptr;
    reg [CW-1:0]         count;

    assign full         = (count == DEPTH);
    assign empty        = (count == 0);
    assign almost_full  = (count >= AF_THRESH);
    assign almost_empty = (count <= AE_THRESH);

    wire do_write = wr_en & ~full;
    wire do_read  = rd_en & ~empty;

    wire [PW-1:0] wr_ptr_nxt = (wr_ptr == DEPTH-1) ? {PW{1'b0}} : wr_ptr + 1'b1;
    wire [PW-1:0] rd_ptr_nxt = (rd_ptr == DEPTH-1) ? {PW{1'b0}} : rd_ptr + 1'b1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr   <= {PW{1'b0}};
            rd_ptr   <= {PW{1'b0}};
            count    <= {CW{1'b0}};
            data_out <= {DATA_WIDTH{1'b0}};
        end else begin
            if (do_write) begin
                mem[wr_ptr] <= data_in;
                wr_ptr      <= wr_ptr_nxt;
            end
            if (do_read) begin
                data_out <= mem[rd_ptr];
                rd_ptr   <= rd_ptr_nxt;
            end
            case ({do_write, do_read})
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

    initial begin
        if (DEPTH < 2)
            $display("sync_fifo ERROR: DEPTH must be at least 2");
        if (AF_THRESH > DEPTH || AE_THRESH >= DEPTH)
            $display("sync_fifo ERROR: thresholds must be below DEPTH");
    end
endmodule
