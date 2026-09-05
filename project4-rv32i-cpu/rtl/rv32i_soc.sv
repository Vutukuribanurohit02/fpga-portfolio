// rv32i_soc.sv - CPU + unified memory. Memory lives here, not inside the
// core, so formal can drive the memory interface as free inputs.
module rv32i_soc #(
    parameter int MEM_BYTES = 8192,
    parameter logic [31:0] RESET_PC = 32'h0
)(
    input  logic clk,
    input  logic rst_n
);

    logic [31:0] instr_addr, instr_data;
    logic [31:0] data_addr, data_wdata, data_rdata;
    logic [3:0]  data_wstrb;

    rv32i_cpu #(.RESET_PC(RESET_PC)) u_cpu (
        .clk(clk), .rst_n(rst_n),
        .instr_addr(instr_addr), .instr_data(instr_data),
        .data_addr(data_addr),   .data_wstrb(data_wstrb),
        .data_wdata(data_wdata), .data_rdata(data_rdata)
    );

    mem #(.MEM_BYTES(MEM_BYTES)) u_mem (
        .clk(clk),
        .instr_addr(instr_addr), .instr_data(instr_data),
        .data_addr(data_addr),   .data_wstrb(data_wstrb),
        .data_wdata(data_wdata), .data_rdata(data_rdata)
    );

endmodule
