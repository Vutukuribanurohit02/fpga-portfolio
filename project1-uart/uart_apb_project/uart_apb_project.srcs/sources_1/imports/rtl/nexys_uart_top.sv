module nexys_uart_top (
    input  logic        CLK100MHZ,
    input  logic        CPU_RESETN,   // active-low reset button
    input  logic [15:0] SW,           // 16 switches
    input  logic        BTNC,         // center button: pulse PSEL+PENABLE (send)
    output logic [15:0] LED,          // 16 LEDs
    output logic        JA1,          // Pmod JA pin 1 -> tx
    input  logic        JA2           // Pmod JA pin 2 -> rx (jumper JA1 to JA2 for loopback)
);

    logic [31:0] prdata;
    logic        pready;

    // SW[3:0]   = PADDR
    // SW[11:4]  = PWDATA[7:0] (byte to send)
    // SW[15]    = PWRITE (1=write, 0=read)
    // BTNC      = triggers one APB transaction (PSEL+PENABLE for 1 cycle)

    logic psel_r, penable_r;
    logic btnc_prev;

    always_ff @(posedge CLK100MHZ or negedge CPU_RESETN) begin
        if (!CPU_RESETN) begin
            psel_r    <= 1'b0;
            penable_r <= 1'b0;
            btnc_prev <= 1'b0;
        end else begin
            btnc_prev <= BTNC;
            if (BTNC && !btnc_prev) begin
                psel_r    <= 1'b1;
                penable_r <= 1'b0; // setup phase this cycle
            end else if (psel_r && !penable_r) begin
                penable_r <= 1'b1; // access phase next cycle
            end else begin
                psel_r    <= 1'b0;
                penable_r <= 1'b0;
            end
        end
    end

    uart_apb u_uart_apb (
        .PCLK     (CLK100MHZ),
        .PRESETn  (CPU_RESETN),
        .PADDR    (SW[3:0]),
        .PWRITE   (SW[15]),
        .PSEL     (psel_r),
        .PENABLE  (penable_r),
        .PWDATA   ({24'h0, SW[11:4]}),
        .PRDATA   (prdata),
        .PREADY   (pready),
        .tx       (JA1),
        .rx       (JA2)
    );

    assign LED = prdata[15:0]; // shows read data / status on LEDs

endmodule