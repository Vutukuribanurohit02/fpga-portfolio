// regfile_bind.sv - Formal property for regfile.sv: x0 always reads zero,
// regardless of write-enable or write address, for all reachable states.
module regfile_props (
    input logic        clk,
    input logic [4:0]  rs1_addr,
    input logic [4:0]  rs2_addr,
    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data
);

    // Property: reading x0 always yields zero.
    always @(posedge clk) begin
        if (rs1_addr == 5'd0)
            assert (rs1_data == 32'd0);
        if (rs2_addr == 5'd0)
            assert (rs2_data == 32'd0);
    end

    always @(posedge clk) begin
        cover (rs1_addr == 5'd0);
        cover (rs2_addr != 5'd0);
    end

endmodule

bind regfile regfile_props regfile_props_inst (
    .clk(clk), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
    .rs1_data(rs1_data), .rs2_data(rs2_data)
);
