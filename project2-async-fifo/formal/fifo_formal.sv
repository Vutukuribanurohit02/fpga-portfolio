`define FORMAL
`include "fifo_bind.sv"

module fifo_formal_top (
    input logic wclk,
    input logic rclk,
    input logic wrst_n,
    input logic rrst_n,
    input logic winc,
    input logic rinc,
    input logic [7:0] wdata
);

    logic [7:0] rdata;
    logic wfull, rempty;
    logic [4:0] wbin_dbg, rbin_dbg, wptr_gray_dbg, rptr_gray_dbg;
    logic [4:0] r2w_sync_meta_dbg, r2w_sync_q_dbg, w2r_sync_meta_dbg, w2r_sync_q_dbg;

    async_fifo #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .wbin_dbg(wbin_dbg), .wptr_gray_dbg(wptr_gray_dbg),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty),
        .rbin_dbg(rbin_dbg), .rptr_gray_dbg(rptr_gray_dbg),
        .r2w_sync_meta_dbg(r2w_sync_meta_dbg), .r2w_sync_q_dbg(r2w_sync_q_dbg),
        .w2r_sync_meta_dbg(w2r_sync_meta_dbg), .w2r_sync_q_dbg(w2r_sync_q_dbg)
    );

    fifo_formal #(.DATA_WIDTH(8), .ADDR_WIDTH(4)) props (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .wbin_dbg(wbin_dbg), .wptr_gray_dbg(wptr_gray_dbg),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty),
        .rbin_dbg(rbin_dbg), .rptr_gray_dbg(rptr_gray_dbg),
        .r2w_sync_meta_dbg(r2w_sync_meta_dbg), .r2w_sync_q_dbg(r2w_sync_q_dbg),
        .w2r_sync_meta_dbg(w2r_sync_meta_dbg), .w2r_sync_q_dbg(w2r_sync_q_dbg)
    );

endmodule
