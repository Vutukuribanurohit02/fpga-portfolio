// wrapper.sv - riscv-formal harness for rv32i_cpu.
// Memory is NOT instantiated: instr_data and data_rdata are free inputs, so
// the solver explores every possible memory response.
//
// Debug observation uses real ports on the core (guarded by `ifdef FORMAL),
// not hierarchical dot-paths: after `prep -flatten`, dot-path taps resolve to
// dump-time constants and report zeros regardless of actual behaviour.
module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
);
	(* keep *) `rvformal_rand_reg [31:0] instr_data;
	(* keep *) `rvformal_rand_reg [31:0] data_rdata;

	(* keep *) wire [31:0] instr_addr;
	(* keep *) wire [31:0] data_addr;
	(* keep *) wire [3:0]  data_wstrb;
	(* keep *) wire [31:0] data_wdata;

	(* keep *) wire [2:0]  dbg_funct3;
	(* keep *) wire        dbg_branch;
	(* keep *) wire        dbg_jump;
	(* keep *) wire        dbg_jalr;
	(* keep *) wire        dbg_branch_taken;
	(* keep *) wire [31:0] dbg_alu_result;
	(* keep *) wire [31:0] dbg_pc;
	(* keep *) wire [31:0] dbg_imm;
	(* keep *) wire [31:0] dbg_rs1_data;
	(* keep *) wire [31:0] dbg_pc_next;

	rv32i_cpu uut (
		.clk        (clock),
		.rst_n      (!reset),
		.instr_addr (instr_addr),
		.instr_data (instr_data),
		.data_addr  (data_addr),
		.data_wstrb (data_wstrb),
		.data_wdata (data_wdata),
		.data_rdata (data_rdata),
		.dbg_funct3       (dbg_funct3),
		.dbg_branch       (dbg_branch),
		.dbg_jump         (dbg_jump),
		.dbg_jalr         (dbg_jalr),
		.dbg_alu_result   (dbg_alu_result),
		.dbg_pc           (dbg_pc),
		.dbg_imm          (dbg_imm),
		.dbg_rs1_data     (dbg_rs1_data),
		.dbg_branch_taken (dbg_branch_taken),
		.dbg_pc_next      (dbg_pc_next),
		`RVFI_CONN
	);
endmodule
