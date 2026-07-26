// pc_bind.sv - Formal top-level: instantiates rv32i_cpu_formal.sv, which
// has debug ports wired via same-scope assigns (no dot-paths, avoiding the
// vacuous-proof issue). Checks branch_taken/pc_next against an independent
// computation.
module pc_formal (
    input logic clk,
    input logic rst_n
);

    logic [2:0]  funct3;
    logic        branch;
    logic        jump;
    logic        jalr;
    logic [31:0] alu_result;
    logic [31:0] pc;
    logic [31:0] imm;
    logic [31:0] rs1_data;
    logic        branch_taken;
    logic [31:0] pc_next;

    rv32i_cpu_formal #(.MEM_BYTES(8192), .RESET_PC(32'h0)) dut (
        .clk(clk), .rst_n(rst_n),
        .dbg_funct3(funct3), .dbg_branch(branch), .dbg_jump(jump), .dbg_jalr(jalr),
        .dbg_alu_result(alu_result), .dbg_pc(pc), .dbg_imm(imm),
        .dbg_rs1_data(rs1_data), .dbg_branch_taken(branch_taken), .dbg_pc_next(pc_next)
    );

    logic expected_branch_taken;
    always_comb begin
        expected_branch_taken = 1'b0;
        if (branch) begin
            case (funct3)
                3'b000:  expected_branch_taken = (alu_result == 32'b0);
                3'b001:  expected_branch_taken = (alu_result != 32'b0);
                3'b100:  expected_branch_taken = alu_result[0];
                3'b101:  expected_branch_taken = ~alu_result[0];
                3'b110:  expected_branch_taken = alu_result[0];
                3'b111:  expected_branch_taken = ~alu_result[0];
                default: expected_branch_taken = 1'b0;
            endcase
        end
    end

    always @(posedge clk) begin
        if (branch)
            assert (branch_taken == expected_branch_taken);
    end

    logic [31:0] expected_pc_next;
    always_comb begin
        if (jump)
            expected_pc_next = jalr
                ? ((rs1_data + imm) & 32'hFFFFFFFE)
                : (pc + imm);
        else if (branch && expected_branch_taken)
            expected_pc_next = pc + imm;
        else
            expected_pc_next = pc + 32'd4;
    end

    always @(posedge clk) begin
        assert (pc_next == expected_pc_next);
    end

    always @(posedge clk) begin
        cover (jump && jalr);
        cover (jump && !jalr);
        cover (branch && expected_branch_taken);
        cover (!jump && !(branch && expected_branch_taken));
    end

endmodule
