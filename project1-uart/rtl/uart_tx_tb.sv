`timescale 1ns/1ps

module uart_tx_tb;

    // ---- Parameters ----
    localparam CLK_PERIOD = 10;      // 100 MHz clock -> 10ns period
    localparam DIV        = 16'd4;   // small divider for fast simulation (not real baud rate)

    // ---- DUT signals ----
    logic       clk;
    logic       rst_n;
    logic       baud_tick;
    logic [7:0] tx_data;
    logic       start_tx;
    logic       tx;
    logic       tx_busy;

    // ---- Instantiate baud_gen to drive baud_tick realistically ----
    baud_gen u_baud_gen (
        .clk       (clk),
        .rst_n     (rst_n),
        .div       (DIV),
        .baud_tick (baud_tick)
    );

    // ---- Instantiate DUT ----
    uart_tx u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .tx_data   (tx_data),
        .start_tx  (start_tx),
        .tx        (tx),
        .tx_busy   (tx_busy)
    );

    // ---- Clock generation ----
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---- Scoreboard / reference model ----
    logic [7:0] expected_byte;
    int         error_count = 0;
    int         check_count = 0;

    // ---- Task: send one byte and self-check the serial output ----
    task automatic send_and_check(input [7:0] data_byte);
        int i;
        begin
            expected_byte = data_byte;
            tx_data  = data_byte;

            // Pulse start_tx for 1 clock cycle
            @(posedge clk);
            start_tx = 1'b1;
            @(posedge clk);
            start_tx = 1'b0;

            // Wait for tx to go low (start bit)
            wait (tx == 1'b0);
            @(posedge clk); #1; // let signals fully settle before sampling
            check_count++;
            if (tx !== 1'b0) begin
                $error("START BIT check failed: expected 0, got %b", tx);
                error_count++;
            end else begin
                $display("[PASS] Start bit correct at time %0t", $time);
            end

            // Sample each data bit at the middle of its bit period
            for (i = 0; i < 8; i++) begin
                repeat (16) @(posedge baud_tick); // wait one full bit period
                @(posedge clk); #1; // let signals fully settle before sampling
                check_count++;
                if (tx !== expected_byte[i]) begin
                    $error("DATA BIT %0d check failed: expected %b, got %b", i, expected_byte[i], tx);
                    error_count++;
                end else begin
                    $display("[PASS] Data bit %0d correct (%b) at time %0t", i, tx, $time);
                end
            end

            // Check stop bit
            repeat (16) @(posedge baud_tick);
            @(posedge clk); #1; // let signals fully settle before sampling
            check_count++;
            if (tx !== 1'b1) begin
                $error("STOP BIT check failed: expected 1, got %b", tx);
                error_count++;
            end else begin
                $display("[PASS] Stop bit correct at time %0t", $time);
            end

            // Confirm tx_busy deasserts and line returns idle
            wait (tx_busy == 1'b0);
            @(posedge clk); #1; // let signals fully settle before sampling
            check_count++;
            if (tx !== 1'b1) begin
                $error("IDLE check failed after transmission: expected tx=1, got %b", tx);
                error_count++;
            end else begin
                $display("[PASS] Returned to idle correctly at time %0t", $time);
            end
        end
    endtask

    // ---- Main test sequence ----
    initial begin
        clk      = 0;
        rst_n    = 0;
        tx_data  = 8'h00;
        start_tx = 1'b0;

        // Reset pulse
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // Test case 1: simple byte
        $display("\n--- Test 1: sending 0xA5 ---");
        send_and_check(8'hA5);

        // Test case 2: all zeros
        $display("\n--- Test 2: sending 0x00 ---");
        send_and_check(8'h00);

        // Test case 3: all ones
        $display("\n--- Test 3: sending 0xFF ---");
        send_and_check(8'hFF);

        // Test case 4: alternating pattern
        $display("\n--- Test 4: sending 0x55 ---");
        send_and_check(8'h55);

        // ---- Final report ----
        $display("\n========================================");
        $display("Total checks: %0d, Errors: %0d", check_count, error_count);
        if (error_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED");
        $display("========================================\n");

        $finish;
    end

endmodule