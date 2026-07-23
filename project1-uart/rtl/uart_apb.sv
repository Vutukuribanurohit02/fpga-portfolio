module uart_apb #(
    parameter ADDR_WIDTH = 4
)(
    // APB interface
    input  logic                    PCLK,
    input  logic                    PRESETn,
    input  logic [ADDR_WIDTH-1:0]   PADDR,
    input  logic                    PWRITE,
    input  logic                    PSEL,
    input  logic                    PENABLE,
    input  logic [31:0]             PWDATA,
    output logic [31:0]             PRDATA,
    output logic                    PREADY,

    // UART physical pins
    output logic                    tx,
    input  logic                    rx
);

    // ---- Register map ----
    localparam ADDR_TXDATA  = 4'h0;
    localparam ADDR_RXDATA  = 4'h4;
    localparam ADDR_STATUS  = 4'h8;
    localparam ADDR_BAUDDIV = 4'hC;

    // ---- Internal registers ----
    logic [7:0]  tx_data_reg;
    logic [7:0]  rx_data_reg;
    logic        tx_busy;
    logic        rx_valid;
    logic [15:0] baud_div;

    logic        apb_write;
    logic        apb_read;
    logic        start_tx;
    logic        baud_tick;

    assign apb_write = PSEL && PENABLE && PWRITE;
    assign apb_read  = PSEL && PENABLE && !PWRITE;
    assign PREADY    = 1'b1; // no wait states for now

    // ---- Write logic ----
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_data_reg <= 8'h0;
            baud_div    <= 16'h0;
            start_tx    <= 1'b0;
        end else begin
            start_tx <= 1'b0; // default: pulse low unless a write happens this cycle
            if (apb_write) begin
                case (PADDR)
                    ADDR_TXDATA: begin
                        tx_data_reg <= PWDATA[7:0];
                        start_tx    <= 1'b1; // pulse for 1 cycle to kick off uart_tx
                    end
                    ADDR_BAUDDIV: baud_div <= PWDATA[15:0];
                    default: ; // RXDATA and STATUS are read-only, ignore writes
                endcase
            end
        end
    end

    // ---- Read logic ----
    always_comb begin
        PRDATA = 32'h0;
        if (apb_read) begin
            case (PADDR)
                ADDR_TXDATA:  PRDATA = {24'h0, tx_data_reg};
                ADDR_RXDATA:  PRDATA = {24'h0, rx_data_reg};
                ADDR_STATUS:  PRDATA = {30'h0, rx_valid, tx_busy};
                ADDR_BAUDDIV: PRDATA = {16'h0, baud_div};
                default:      PRDATA = 32'h0;
            endcase
        end
    end

    // ---- Baud rate generator ----
    baud_gen u_baud_gen (
        .clk       (PCLK),
        .rst_n     (PRESETn),
        .div       (baud_div),
        .baud_tick (baud_tick)
    );

    // ---- UART TX core ----
    uart_tx u_uart_tx (
        .clk       (PCLK),
        .rst_n     (PRESETn),
        .baud_tick (baud_tick),
        .tx_data   (tx_data_reg),
        .start_tx  (start_tx),
        .tx        (tx),
        .tx_busy   (tx_busy)
    );

    // ---- UART RX core ----
    uart_rx u_uart_rx (
        .clk       (PCLK),
        .rst_n     (PRESETn),
        .baud_tick (baud_tick),
        .rx        (rx),
        .rx_data   (rx_data_reg),
        .rx_valid  (rx_valid)
    );

endmodule