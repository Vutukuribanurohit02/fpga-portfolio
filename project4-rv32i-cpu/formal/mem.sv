// mem.sv - Unified byte-addressable memory (Von Neumann): instruction fetch +
// data load/store share one array. Combinational reads (single-cycle CPU
// needs same-cycle visibility), synchronous writes.
module mem #(
    parameter int MEM_BYTES = 8192  // 8KB default; must be power of 2
)(
    input  logic        clk,

    // Instruction fetch port (word, always aligned)
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_data,

    // Data load/store port
    input  logic [31:0] data_addr,
    input  logic [2:0]  funct3,      // load/store width+sign, RV32I encoding
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [31:0] wdata,
    output logic [31:0] rdata
);

    logic [7:0] bytes [0:MEM_BYTES-1];

    // ---- Instruction fetch: word-aligned combinational read ----
    assign instr_data = {bytes[instr_addr+3], bytes[instr_addr+2],
                          bytes[instr_addr+1], bytes[instr_addr]};

    // ---- Data read: combinational, width + sign per funct3 ----
    logic [7:0]  rb;
    logic [15:0] rh;
    logic [31:0] rw;

    assign rb = bytes[data_addr];
    assign rh = {bytes[data_addr+1], bytes[data_addr]};
    assign rw = {bytes[data_addr+3], bytes[data_addr+2],
                 bytes[data_addr+1], bytes[data_addr]};

    always_comb begin
        rdata = 32'b0;
        if (mem_read) begin
            case (funct3)
                3'b000: rdata = {{24{rb[7]}},  rb};   // LB  (sign-extend)
                3'b001: rdata = {{16{rh[15]}}, rh};   // LH  (sign-extend)
                3'b010: rdata = rw;                   // LW
                3'b100: rdata = {24'b0, rb};           // LBU (zero-extend)
                3'b101: rdata = {16'b0, rh};           // LHU (zero-extend)
                default: rdata = 32'b0;
            endcase
        end
    end

    // ---- Data write: synchronous, width per funct3 ----
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB
                    bytes[data_addr] <= wdata[7:0];
                end
                3'b001: begin // SH
                    bytes[data_addr]   <= wdata[7:0];
                    bytes[data_addr+1] <= wdata[15:8];
                end
                3'b010: begin // SW
                    bytes[data_addr]   <= wdata[7:0];
                    bytes[data_addr+1] <= wdata[15:8];
                    bytes[data_addr+2] <= wdata[23:16];
                    bytes[data_addr+3] <= wdata[31:24];
                end
                default: ;
            endcase
        end
    end

`ifdef SIMULATION
    // Load compiled program into memory at simulation start.
    // Filename is fixed here for this project's single test program;
    // guarded so this never affects synthesis or formal views.
    initial begin
        $readmemh("bubble_sort.hex", bytes);
    end
`endif

endmodule
