// rv32i_cpu_tb.sv - Top-level testbench: runs the compiled bubble_sort
// program on the CPU and checks the array is correctly sorted in memory.
`timescale 1ns/1ps
`define SIMULATION

module rv32i_cpu_tb;

    logic clk = 0;
    logic rst_n = 0;

    rv32i_cpu #(.MEM_BYTES(8192), .RESET_PC(32'h0)) dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // Array base address: 'arr' was placed at 0x130 per the disassembly
    // (a0 = 304 = 0x130 loaded in _start). N = 8 elements, 4 bytes each.
    localparam int ARR_BASE = 32'h150;
    localparam int N = 8;

    int expected [0:N-1];
    int errors = 0;

    initial begin
        expected[0] = 1; expected[1] = 2; expected[2] = 3; expected[3] = 4;
        expected[4] = 5; expected[5] = 7; expected[6] = 8; expected[7] = 9;
    end

    task automatic dump_array(string label);
        int v;
        $display("---- %s ----", label);
        for (int i = 0; i < N; i++) begin
            v = {dut.u_mem.bytes[ARR_BASE + i*4 + 3],
                 dut.u_mem.bytes[ARR_BASE + i*4 + 2],
                 dut.u_mem.bytes[ARR_BASE + i*4 + 1],
                 dut.u_mem.bytes[ARR_BASE + i*4 + 0]};
            $display("  arr[%0d] = %0d", i, v);
        end
    endtask

    initial begin
        // Reset for a few cycles
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        dump_array("BEFORE (should be unsorted: 5 2 9 1 7 3 8 4)");

        // Run for enough cycles to guarantee completion of the sort
        repeat (3000) @(posedge clk);

        dump_array("AFTER");

        // Check sorted result
        for (int i = 0; i < N; i++) begin
            int v;
            v = {dut.u_mem.bytes[ARR_BASE + i*4 + 3],
                 dut.u_mem.bytes[ARR_BASE + i*4 + 2],
                 dut.u_mem.bytes[ARR_BASE + i*4 + 1],
                 dut.u_mem.bytes[ARR_BASE + i*4 + 0]};
            if (v !== expected[i]) begin
                errors++;
                $display("FAIL: arr[%0d] = %0d, expected %0d", i, v, expected[i]);
            end
        end

        $display("----------------------------------------");
        if (errors == 0)
            $display("ALL CHECKS PASSED: array correctly sorted by compiled C running on rv32i_cpu");
        else
            $display("TESTS FAILED: %0d mismatches", errors);

        $finish;
    end

endmodule
