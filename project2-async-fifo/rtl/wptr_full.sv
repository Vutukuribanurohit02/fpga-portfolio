// wptr_full.sv - Write pointer (binary + Gray) and full flag generation
module wptr_full #(
    parameter int ADDR_WIDTH = 4
)(
    input  logic                    wclk,
    input  logic                    wrst_n,
    input  logic                    winc,
    output logic [ADDR_WIDTH-1:0]   waddr_out,
    output logic [ADDR_WIDTH:0]     wptr_gray,       // Gray pointer, sent to read domain
    output logic [ADDR_WIDTH:0]     wbin_dbg,        // debug: binary pointer for formal checks
    input  logic [ADDR_WIDTH:0]     wq2_rptr_gray,   // read pointer, synchronized into write domain
    output logic                    wfull
);

    logic [ADDR_WIDTH:0] wbin, wbin_next;
    logic [ADDR_WIDTH:0] wgray_next;

    assign wbin_next   = wbin + (winc & ~wfull);
    assign wgray_next  = (wbin_next >> 1) ^ wbin_next;  // binary-to-Gray

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin      <= '0;
            wptr_gray <= '0;
        end else begin
            wbin      <= wbin_next;
            wptr_gray <= wgray_next;
        end
    end

    assign waddr_out = wbin[ADDR_WIDTH-1:0];
    assign wbin_dbg  = wbin;  // drop MSB (wrap bit) for RAM addressing

    // Full condition: next write Gray pointer equals read pointer Gray
    // with top two bits inverted (Cummings' classic comparison)
    logic wfull_next;
    assign wfull_next = (wgray_next == {~wq2_rptr_gray[ADDR_WIDTH:ADDR_WIDTH-1],
                                          wq2_rptr_gray[ADDR_WIDTH-2:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n)
            wfull <= 1'b0;
        else
            wfull <= wfull_next;
    end

endmodule
