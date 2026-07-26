// rptr_empty.sv - Read pointer (binary + Gray) and empty flag generation
module rptr_empty #(
    parameter int ADDR_WIDTH = 4
)(
    input  logic                    rclk,
    input  logic                    rrst_n,
    input  logic                    rinc,
    output logic [ADDR_WIDTH-1:0]   raddr_out,
    output logic [ADDR_WIDTH:0]     rptr_gray,       // Gray pointer, sent to write domain
    output logic [ADDR_WIDTH:0]     rbin_dbg,        // debug: binary pointer for formal checks
    input  logic [ADDR_WIDTH:0]     rq2_wptr_gray,   // write pointer, synchronized into read domain
    output logic                    rempty
);

    logic [ADDR_WIDTH:0] rbin, rbin_next;
    logic [ADDR_WIDTH:0] rgray_next;

    assign rbin_next  = rbin + (rinc & ~rempty);
    assign rgray_next = (rbin_next >> 1) ^ rbin_next;  // binary-to-Gray

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin      <= '0;
            rptr_gray <= '0;
        end else begin
            rbin      <= rbin_next;
            rptr_gray <= rgray_next;
        end
    end

    assign raddr_out = rbin[ADDR_WIDTH-1:0];
    assign rbin_dbg  = rbin;

    // Empty condition: next read Gray pointer equals synchronized write pointer Gray exactly
    logic rempty_next;
    assign rempty_next = (rgray_next == rq2_wptr_gray);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n)
            rempty <= 1'b1;
        else
            rempty <= rempty_next;
    end

endmodule
