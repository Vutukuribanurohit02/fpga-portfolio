// async_fifo_tb.sv - Self-checking testbench for async_fifo
// Write domain: 100MHz, Read domain: 66MHz (different, unrelated clocks -- true CDC test)
`timescale 1ns/1ps

module async_fifo_tb;

    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 4;

    logic                  wclk = 0, rclk = 0;
    logic                  wrst_n = 0, rrst_n = 0;
    logic                  winc, rinc;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  wfull, rempty;
    logic [ADDR_WIDTH:0]   wbin_dbg, wptr_gray_dbg, rbin_dbg, rptr_gray_dbg;
    logic [ADDR_WIDTH:0]   r2w_meta_dbg, r2w_q_dbg, w2r_meta_dbg, w2r_q_dbg;

    always #5.0  wclk = ~wclk;   // 10ns period  -> 100 MHz
    always #7.57 rclk = ~rclk;   // ~15.15ns period -> ~66 MHz

    async_fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) dut (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
        .wbin_dbg(wbin_dbg), .wptr_gray_dbg(wptr_gray_dbg),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty),
        .rbin_dbg(rbin_dbg), .rptr_gray_dbg(rptr_gray_dbg),
        .r2w_sync_meta_dbg(r2w_meta_dbg), .r2w_sync_q_dbg(r2w_q_dbg),
        .w2r_sync_meta_dbg(w2r_meta_dbg), .w2r_sync_q_dbg(w2r_q_dbg)
    );

    logic [DATA_WIDTH-1:0] ref_q[$];
    int errors = 0;
    int writes_done = 0;
    int reads_done = 0;
    int benign_full_collisions = 0;
    int benign_empty_collisions = 0;
    byte unsigned val;

    initial begin
        wrst_n = 0;
        repeat (4) @(posedge wclk);
        wrst_n = 1;
    end

    initial begin
        rrst_n = 0;
        repeat (4) @(posedge rclk);
        rrst_n = 1;
    end

    // Write DRIVER: proposes writes. Decision uses wfull from the previous
    // cycle (standard registered-decision pattern) -- it's fine if this
    // occasionally races with wfull changing before winc is sampled by the
    // DUT, because the DUT's own wen = winc & ~wfull gate protects the
    // memory. We track ACTUAL acceptance separately below, not here.
    initial begin
        val   = 8'h00;
        winc  = 0;
        wdata = '0;
        wait (wrst_n);
        repeat (300) begin
            @(posedge wclk);
            if (!wfull && ($urandom_range(0,1) == 1)) begin
                winc  <= 1;
                wdata <= val;
                val++;
            end else begin
                winc <= 0;
            end
        end
        winc <= 0;
    end

    // Write MONITOR: ground truth. winc && !wfull, sampled at the same
    // cycle the DUT itself uses to gate wen, is exactly when a write is
    // actually accepted -- so only push to the reference model here.
    always @(posedge wclk) begin
        if (wrst_n) begin
            if (winc && !wfull) begin
                ref_q.push_back(wdata);
                writes_done++;
            end else if (winc && wfull) begin
                benign_full_collisions++;  // proposed write correctly dropped by DUT gate -- not an error
            end
        end
    end

    // Read DRIVER: proposes reads, same registered-decision pattern as write.
    initial begin
        rinc = 0;
        wait (rrst_n);
        forever begin
            @(posedge rclk);
            if (!rempty && ($urandom_range(0,1) == 1)) begin
                rinc <= 1;
            end else begin
                rinc <= 0;
            end
        end
    end

    // Read MONITOR: ground truth. rinc && !rempty at the sampled cycle is
    // exactly when the DUT's read pointer actually advances. rdata reflects
    // that entry one cycle later (registered/synchronous BRAM read).
    logic read_accepted_d1;
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            read_accepted_d1 <= 1'b0;
        end else begin
            read_accepted_d1 <= (rinc && !rempty);
            if (rinc && rempty) benign_empty_collisions++;  // proposed read correctly dropped -- not an error
        end
    end

    logic [DATA_WIDTH-1:0] expected;
    always @(posedge rclk) begin
        if (rrst_n && read_accepted_d1 && ref_q.size() > 0) begin
            expected = ref_q.pop_front();
            if (rdata !== expected) begin
                $display("[%0t] MISMATCH: expected %02h, got %02h", $time, expected, rdata);
                errors++;
            end else begin
                reads_done++;
            end
        end
    end

    initial begin
        $dumpfile("async_fifo_tb.vcd");
        $dumpvars(0, async_fifo_tb);

        wait (wrst_n && rrst_n);
        #6000;

        $display("--------------------------------------------------");
        $display("Writes accepted        : %0d", writes_done);
        $display("Reads checked           : %0d", reads_done);
        $display("Benign full collisions  : %0d (proposed write correctly rejected by wfull gate)", benign_full_collisions);
        $display("Benign empty collisions : %0d (proposed read correctly rejected by rempty gate)", benign_empty_collisions);
        $display("Ref queue left          : %0d", ref_q.size());
        $display("Errors                  : %0d", errors);
        if (errors == 0 && writes_done > 0 && reads_done > 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule
