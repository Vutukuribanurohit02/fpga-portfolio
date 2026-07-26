// async_fifo.sv - Top-level asynchronous FIFO
// Based on Cummings' SNUG 2002 dual-clock FIFO architecture
module async_fifo #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
)(
    // Write domain
    input  logic                    wclk,
    input  logic                    wrst_n,
    input  logic                    winc,
    input  logic [DATA_WIDTH-1:0]   wdata,
    output logic                    wfull,
    output logic [ADDR_WIDTH:0]     wbin_dbg,
    output logic [ADDR_WIDTH:0]     wptr_gray_dbg,

    // Read domain
    input  logic                    rclk,
    input  logic                    rrst_n,
    input  logic                    rinc,
    output logic [DATA_WIDTH-1:0]   rdata,
    output logic [ADDR_WIDTH:0]     rbin_dbg,
    output logic [ADDR_WIDTH:0]     rptr_gray_dbg,
    output logic                    rempty,

    // Synchronizer debug ports (formal only)
    output logic [ADDR_WIDTH:0]     r2w_sync_meta_dbg,  // read ptr, meta stage, write domain
    output logic [ADDR_WIDTH:0]     r2w_sync_q_dbg,      // read ptr, synced, write domain
    output logic [ADDR_WIDTH:0]     w2r_sync_meta_dbg,  // write ptr, meta stage, read domain
    output logic [ADDR_WIDTH:0]     w2r_sync_q_dbg       // write ptr, synced, read domain
);

    logic [ADDR_WIDTH-1:0] waddr, raddr;
    logic [ADDR_WIDTH:0]   wptr_gray, rptr_gray;
    logic [ADDR_WIDTH:0]   wq2_rptr_gray;   // read ptr synced into write domain
    logic [ADDR_WIDTH:0]   rq2_wptr_gray;   // write ptr synced into read domain

    // Write-domain pointer + full flag
    wptr_full #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr_full (
        .wclk           (wclk),
        .wrst_n         (wrst_n),
        .winc           (winc),
        .waddr_out      (waddr),
        .wptr_gray      (wptr_gray),
        .wbin_dbg       (wbin_dbg),
        .wq2_rptr_gray  (wq2_rptr_gray),
        .wfull          (wfull)
    );

    // Read-domain pointer + empty flag
    rptr_empty #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr_empty (
        .rclk           (rclk),
        .rrst_n         (rrst_n),
        .rinc           (rinc),
        .raddr_out      (raddr),
        .rptr_gray      (rptr_gray),
        .rbin_dbg       (rbin_dbg),
        .rq2_wptr_gray  (rq2_wptr_gray),
        .rempty         (rempty)
    );

    // Synchronize read pointer (Gray) into write clock domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_rptr (
        .clk        (wclk),
        .rst_n      (wrst_n),
        .d          (rptr_gray),
        .q          (wq2_rptr_gray),
        .meta_dbg   (r2w_sync_meta_dbg)
    );
    assign r2w_sync_q_dbg = wq2_rptr_gray;

    // Synchronize write pointer (Gray) into read clock domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_wptr (
        .clk        (rclk),
        .rst_n      (rrst_n),
        .d          (wptr_gray),
        .q          (rq2_wptr_gray),
        .meta_dbg   (w2r_sync_meta_dbg)
    );
    assign w2r_sync_q_dbg = rq2_wptr_gray;

    // Dual-port memory
    assign wptr_gray_dbg = wptr_gray;
    assign rptr_gray_dbg = rptr_gray;

    fifo_mem #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_fifo_mem (
        .wclk   (wclk),
        .wen    (winc & ~wfull),
        .waddr  (waddr),
        .wdata  (wdata),
        .rclk   (rclk),
        .raddr  (raddr),
        .rdata  (rdata)
    );

endmodule
