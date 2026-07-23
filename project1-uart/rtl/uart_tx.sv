module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic        baud_tick,   // 16x oversampled tick from baud_gen
    input  logic [7:0]  tx_data,
    input  logic        start_tx,    // pulse high for 1 cycle to begin transmission
    output logic        tx,          // serial output line
    output logic        tx_busy
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

    assign tx_busy = (state != IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            tx         <= 1'b1;   // idle line is high
            tick_count <= 4'h0;
            bit_index  <= 3'h0;
            shift_reg  <= 8'h0;
        end else begin
            case (state)

                IDLE: begin
                    tx <= 1'b1;
                    if (start_tx) begin
                        shift_reg  <= tx_data;
                        state      <= START_BIT;
                        tick_count <= 4'h0;
                    end
                end

                START_BIT: begin
                    tx <= 1'b0;  // start bit is always 0
                    if (baud_tick) begin
                        if (tick_count == 4'd15) begin
                            tick_count <= 4'h0;
                            bit_index  <= 3'h0;
                            state      <= DATA_BITS;
                        end else begin
                            tick_count <= tick_count + 1'b1;
                        end
                    end
                end

                DATA_BITS: begin
                    tx <= shift_reg[bit_index];
                    if (baud_tick) begin
                        if (tick_count == 4'd15) begin
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
                    tx <= 1'b1;  // stop bit is always 1
                    if (baud_tick) begin
                        if (tick_count == 4'd15) begin
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