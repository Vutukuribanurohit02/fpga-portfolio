// decoder_tb.sv - Self-checking testbench for decoder.sv immediate generation
`timescale 1ns/1ps

module decoder_tb;

    logic [31:0] instr;
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    logic [31:0] imm;

    int errors = 0;
    int checks = 0;

    decoder dut (
        .instr(instr), .opcode(opcode), .rd(rd), .funct3(funct3),
        .rs1(rs1), .rs2(rs2), .funct7(funct7), .imm(imm)
    );

    task check_imm(input [31:0] i, input [31:0] expected, input string label);
        instr = i;
        #1;
        checks++;
        if (imm !== expected) begin
            errors++;
            $display("FAIL [%s]: instr=%h  expected imm=%h  got imm=%h", label, i, expected, imm);
        end else begin
            $display("PASS [%s]: instr=%h  imm=%h", label, i, imm);
        end
    endtask

    initial begin
        // I-type: ADDI x1, x0, 5   -> imm = 5
        // funct3=000 opcode=0010011 rd=00001 rs1=00000 imm=000000000101
        check_imm(32'b000000000101_00000_000_00001_0010011, 32'd5, "ADDI +5");

        // I-type negative: ADDI x1, x0, -1 -> imm = 0xFFFFFFFF
        check_imm(32'b111111111111_00000_000_00001_0010011, 32'hFFFFFFFF, "ADDI -1");

        // S-type: SW x2, 8(x1) -> imm = 8
        // imm[11:5]=0000000 rs2=00010 rs1=00001 funct3=010 imm[4:0]=01000 opcode=0100011
        check_imm(32'b0000000_00010_00001_010_01000_0100011, 32'd8, "SW +8");

        // S-type negative: SW x2, -4(x1) -> imm = 0xFFFFFFFC
        // imm = -4 = 12'b111111111100 -> imm[11:5]=1111111 imm[4:0]=11100
        check_imm(32'b1111111_00010_00001_010_11100_0100011, 32'hFFFFFFFC, "SW -4");

        // B-type: BEQ x1, x2, +8
        // imm=8=0b0000000000001000 (13-bit signed, bit0 implicit 0)
        // imm[12]=0 imm[10:5]=000000 rs2=00010 rs1=00001 funct3=000 imm[4:1]=0100 imm[11]=0 opcode=1100011
        check_imm(32'b0_000000_00010_00001_000_0100_0_1100011, 32'd8, "BEQ +8");

        // U-type: LUI x1, 0x12345
        // imm[31:12]=0x12345 rd=00001 opcode=0110111
        check_imm(32'b00010010001101000101_00001_0110111, 32'h12345000, "LUI 0x12345");

        // J-type: JAL x1, +16
        // imm=16=0b0000000000010000 (21-bit signed, bit0 implicit 0)
        // imm[20]=0 imm[10:1]=0000001000 imm[11]=0 imm[19:12]=00000000 rd=00001 opcode=1101111
        check_imm(32'b0_0000001000_0_00000000_00001_1101111, 32'd16, "JAL +16");

        $display("----------------------------------------");
        $display("Total checks: %0d, Errors: %0d", checks, errors);
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED");
        $finish;
    end

endmodule
