module uart_rx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick,   // 16x oversampled tick from baud_gen
    input  logic       rx,          // serial input line
    output logic [7:0] rx_data,
    output logic       rx_valid     // pulses high for 1 cycle when a byte is ready
);

    typedef enum logic [1:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } state_t;

    state_t state;
    logic [3:0] tick_count;   // counts 0-15 within each bit period
    logic [2:0] bit_index;    // counts which of the 8 data bits we're on
    logic [7:0] shift_reg;

    // ---- Synchronize rx to avoid metastability (2-flop synchronizer) ----
    logic rx_sync0, rx_sync1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            tick_count <= 4'h0;
            bit_index  <= 3'h0;
            shift_reg  <= 8'h0;
            rx_data    <= 8'h0;
            rx_valid   <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // default: pulse low unless a byte completes this cycle

            case (state)

                IDLE: begin
                    if (rx_sync1 == 1'b0) begin // detected falling edge -> possible start bit
                        state      <= START_BIT;
                        tick_count <= 4'h0;
                    end
                end

                START_BIT: begin
                    if (baud_tick) begin
                        if (tick_count == 4'd7) begin
                            // sample at the middle of the start bit to confirm it's real
                            if (rx_sync1 == 1'b0) begin
                                tick_count <= tick_count + 1'b1; // continue to data bits
                            end else begin
                                state <= IDLE; // false start (glitch), go back to idle
                            end
                        end else if (tick_count == 4'd15) begin
                            tick_count <= 4'h0;
                            bit_index  <= 3'h0;
                            state      <= DATA_BITS;
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end

                DATA_BITS: begin
                    if (baud_tick) begin
                        if (tick_count == 4'd7) begin
                            // sample at the middle of each data bit
                            shift_reg[bit_index] <= rx_sync1;
                            tick_count <= tick_count + 1'b1;
                        end else if (tick_count == 4'd15) begin
                            tick_count <= 4'h0;
                            if (bit_index == 3'd7) begin
                                state <= STOP_BIT;
                            end else begin
                                bit_index <= bit_index + 1'b1;
                            end
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end

                STOP_BIT: begin
                    if (baud_tick) begin
                        if (tick_count == 4'd7) begin
                            // sample at the middle of the stop bit to confirm framing
                            if (rx_sync1 == 1'b1) begin
                                rx_data  <= shift_reg;
                                rx_valid <= 1'b1; // valid byte received
                            end
                            // if stop bit is wrong, silently drop (could add error flag later)
                            tick_count <= tick_count + 1'b1;
                        end else if (tick_count == 4'd15) begin
                            tick_count <= 4'h0;
                            state      <= IDLE;
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule