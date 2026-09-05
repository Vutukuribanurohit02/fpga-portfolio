// mem.sv - Unified byte-addressable memory (Von Neumann): instruction fetch +
// data load/store share one array. Presents a plain word bus: reads return the
// raw aligned word, writes are byte-strobed. Sign/zero extension and byte
// selection belong to the load instruction and live in the CPU.
module mem #(
    parameter int MEM_BYTES = 8192
)(
    input  logic        clk,

    // Instruction fetch (word, always aligned)
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_data,

    // Data port: data_addr is word-aligned; wstrb selects bytes to write
    input  logic [31:0] data_addr,
    input  logic [3:0]  data_wstrb,
    input  logic [31:0] data_wdata,
    output logic [31:0] data_rdata
);

    logic [7:0] bytes [0:MEM_BYTES-1];

    assign instr_data = {bytes[instr_addr+3], bytes[instr_addr+2],
                         bytes[instr_addr+1], bytes[instr_addr]};

    assign data_rdata = {bytes[data_addr+3], bytes[data_addr+2],
                         bytes[data_addr+1], bytes[data_addr]};

    always_ff @(posedge clk) begin
        if (data_wstrb[0]) bytes[data_addr]   <= data_wdata[7:0];
        if (data_wstrb[1]) bytes[data_addr+1] <= data_wdata[15:8];
        if (data_wstrb[2]) bytes[data_addr+2] <= data_wdata[23:16];
        if (data_wstrb[3]) bytes[data_addr+3] <= data_wdata[31:24];
    end

`ifdef SIMULATION
    initial begin
        $readmemh("bubble_sort.hex", bytes);
    end
`endif

endmodule
