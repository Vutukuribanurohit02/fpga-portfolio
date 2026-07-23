module baud_gen (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [15:0] div,       // tick_div value from APB register
    output logic         baud_tick // pulses high for 1 cycle, 16x per bit period
);

    logic [15:0] counter;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= 16'h0;
            baud_tick <= 1'b0;
        end else if (counter == div - 1) begin
            counter   <= 16'h0;
            baud_tick <= 1'b1;   // fire the tick
        end else begin
            counter   <= counter + 1'b1;
            baud_tick <= 1'b0;
        end
    end

endmodule