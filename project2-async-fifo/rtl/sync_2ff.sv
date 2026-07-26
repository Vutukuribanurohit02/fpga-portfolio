// sync_2ff.sv - Parameterized 2-flop synchronizer for CDC
module sync_2ff #(
    parameter int WIDTH = 4
)(
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q,
    output logic [WIDTH-1:0] meta_dbg   // formal debug: expose meta stage
);

    logic [WIDTH-1:0] meta;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta <= '0;
            q    <= '0;
        end else begin
            meta <= d;
            q    <= meta;
        end
    end

    assign meta_dbg = meta;

endmodule
