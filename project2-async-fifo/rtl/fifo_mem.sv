// fifo_mem.sv - Dual-port RAM for async FIFO
module fifo_mem #(
    parameter int DATA_WIDTH = 8,
    parameter int ADDR_WIDTH = 4
)(
    input  logic                   wclk,
    input  logic                   wen,
    input  logic [ADDR_WIDTH-1:0]  waddr,
    input  logic [DATA_WIDTH-1:0]  wdata,

    input  logic                   rclk,
    input  logic [ADDR_WIDTH-1:0]  raddr,
    output logic [DATA_WIDTH-1:0]  rdata
);

    localparam int DEPTH = 1 << ADDR_WIDTH;

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge wclk) begin
        if (wen)
            mem[waddr] <= wdata;
    end

    // Synchronous read (registered output avoids read-during-write glitch issues on FPGA BRAM)
    always_ff @(posedge rclk) begin
        rdata <= mem[raddr];
    end

endmodule
