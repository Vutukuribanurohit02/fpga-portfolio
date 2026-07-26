// regfile.sv - RV32I register file: 32 x 32-bit, x0 hardwired to zero
module regfile (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,

    input  logic        we,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data
);

    logic [31:0] regs [1:31];  // x1..x31; x0 is not stored, always reads 0

    // Combinational read. No same-cycle write bypass: this is a single-cycle
    // (non-pipelined) CPU, so each instruction's register write commits at the
    // clock edge and is naturally visible to the *next* instruction's read via
    // the flip-flops. A same-cycle rd==rs1/rs2 bypass is unnecessary here and
    // was previously creating a real combinational loop (rs1_data -> rd_data ->
    // alu_result -> rs1_data) that hung simulation.
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i <= 31; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule
