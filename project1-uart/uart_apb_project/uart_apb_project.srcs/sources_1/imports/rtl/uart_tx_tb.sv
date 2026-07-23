`timescale 1ns/1ps

module uart_rx_tb;

    localparam CLK_PERIOD = 10;
    localparam DIV        = 16'd4;

    logic       clk;
    logic       rst_n;
    logic       baud_tick;
    logic       rx;
    logic [7:0] rx_data;
    logic       rx_valid;

    baud_gen u_baud_gen (
        .clk       (clk),
        .rst_n     (rst_n),
        .div       (DIV),
        .baud_tick (baud_tick)
    );

    uart_rx u_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .rx        (rx),
        .rx_data   (rx_data),
        .rx_valid  (rx_valid)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    int error_count = 0;
    int check_count = 0;

    task automatic send_byte(input [7:0] data_byte);
        int i;
        begin
            rx = 1'b0;
            repeat (16) @(posedge baud_tick);

            for (i = 0; i < 8; i++) begin
                rx = data_byte[i];
                repeat (16) @(posedge baud_tick);
            end

            rx = 1'b1;
            repeat (16) @(posedge baud_tick);
        end
    endtask

    task automatic send_and_check(input [7:0] data_byte);
        integer timeout_cycles;
        begin
            send_byte(data_byte);

            timeout_cycles = 0;
            while (!rx_valid && timeout_cycles < 50) begin
                @(posedge clk);
                timeout_cycles = timeout_cycles + 1;
            end

            if (!rx_valid) begin
                $error("TIMEOUT waiting for rx_valid for byte 0x%0h", data_byte);
            end

            @(posedge clk); #1;
            check_count++;
            if (rx_data !== data_byte) begin
                $error("RX DATA MISMATCH: expected 0x%0h, got 0x%0h", data_byte, rx_data);
                error_count++;
            end else begin
                $display("[PASS] Received 0x%0h correctly at time %0t", rx_data, $time);
            end
        end
    endtask

    initial begin
        clk    = 0;
        rst_n  = 0;
        rx     = 1'b1;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        $display("\n--- Test 1: receiving 0xA5 ---");
        send_and_check(8'hA5);

        $display("\n--- Test 2: receiving 0x00 ---");
        send_and_check(8'h00);

        $display("\n--- Test 3: receiving 0xFF ---");
        send_and_check(8'hFF);

        $display("\n--- Test 4: receiving 0x55 ---");
        send_and_check(8'h55);

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