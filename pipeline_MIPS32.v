module pipeline_MIPS32 (clk1, clk2);

    input clk1, clk2;
    reg [31:0] R[31:0]; // REGISTER BANK
    reg [31:0] Mem[0:1023];
    reg [31:0] PC, IF_ID_IR, IF_ID_NPC;// latch between IF_ID
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A,ID_EX_B, ID_EX_Imm;
    reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type;
    reg [31:0] EX_MEM_IR, EX_MEM_ALUout, EX_MEM_B;
    reg EX_MEM_cond;
    reg[31:0] MEM_WB_IR, MEM_WB_ALUout, MEM_WB_LMD;


    // now set the parameters and five each instruction code a name, for increasing readability.
    // We can have in total 64 instruction(encoded in 6 bits) but we have taken 14 basic instructions thruogh which otheres can also be implemented.
    parameter       ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011, 
                    SLT = 6'b000100, MUL = 6'b000101, LW = 6'b001000, SW = 6'b001001,
                    ADDI = 6'b001010, SUBI = 6'b001011, SLTI = 6'b001100, BNEQZ = 6'b001101,
                    BEQZ = 6'b001110, HLT = 6'b111111;

    reg HALTED;
    reg Branch_Taken;

    parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE = 3'b011,
              BRANCH = 3'b100, HALT = 3'b101;

/*                               ID stage                    */
    always @(posedge clk2)
        if(HALTED == 0)
        begin 
            // checking if in the fiven instruction reg rs is zero or not
            if( IF_ID_IR[25:21] == 5'b00000)  ID_EX_A <= 0;
            // rs 
            else ID_EX_A <= #2 R[IF_ID_IR[25:21]]; 

            // rt
            if( IF_ID_IR[20:16] == 5'b00000)  ID_EX_B <= 0;
            else ID_EX_B <= #2 R[IF_ID_IR[20:16]]; 

            ID_EX_NPC <= #2 IF_ID_NPC;
            ID_EX_IR <= #2 IF_ID_IR;
            // Sign extention done here: the last 16th bit is extended till to get a 32bit no., it doesnt change the value of the number.
            ID_EX_Imm <= #2 {{16{(IF_ID_IR[15])}}, {IF_ID_IR[15:0]}};

            case( IF_ID_IR[31:26])
                ADD, SUB, AND, OR, SLT, MUL: ID_EX_type <= #2 RR_ALU;
                ADDI, SUBI, SLTI :            ID_EX_type <= #2 RM_ALU;
                LW:                           ID_EX_type <= #2 LOAD;
                SW:                           ID_EX_type <= #2 STORE;
                BNEQZ, BEQZ:                  ID_EX_type <= #2 BRANCH;
                HLT:                          ID_EX_type <= #2 HALT;
                default:                      ID_EX_type <= #2 HALT;



            endcase
        end


/*                               EX stage                    */

 always @(posedge clk2)
        if(HALTED == 0)
        begin 
            EX_MEM_type <= #2 ID_EX_type;
            EX_MEM_IR <= #2 ID_EX_IR;
            Branch_Taken <= #2 0;

            case(ID_EX_type)
            RR_ALU: begin
                        case(ID_EX_IR[31:26])
                             ADD:    EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B;
                             SUB:    EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_B;
                             AND:    EX_MEM_ALUout <= #2 ID_EX_A & ID_EX_B;
                             OR:     EX_MEM_ALUout <= #2 ID_EX_A | ID_EX_B;
                             SLT:    EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_B; 
                             MUL:    EX_MEM_ALUout <= #2 ID_EX_A * ID_EX_B; 
                              default:EX_MEM_ALUout <= #2 32'hxxxxxxxx; 

                        endcase
                    end
            
     // Immediate stage code:
RM_ALU: begin
            case (ID_EX_IR[31:26])
            ADDI:    EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
            SUBI:    EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_Imm;
            SLTI:    EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_Imm;
            default: EX_MEM_ALUout <= #2 32'hxxxxxxxx;

            endcase     
        end
    LOAD, STORE:
                begin
                    EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
                    EX_MEM_B <= #2 ID_EX_B;
                end
    BRANCH:
                begin
                    EX_MEM_ALUout <= #2 ID_EX_NPC + ID_EX_Imm;
                    EX_MEM_cond <= #2 (ID_EX_A == 0);
                end
        endcase
    end

/*                               MEM stage                    */

always @(posedge clk2)
        if(HALTED == 0)
        begin 
            MEM_WB_type <= EX_MEM_type;
            MEM_WB_IR <= #2 EX_MEM_IR;

            case(EX_MEM_type)

                RR_ALU,RM_ALU:        MEM_WB_ALUout <= #2 EX_MEM_ALUout;

                LOAD:                 MEM_WB_LMD <= #2 Mem[EX_MEM_ALUout];

                STORE:    if (Branch_Taken == 0)  Mem[EX_MEM_ALUout] <= #2 EX_MEM_B;

            endcase

        end
        /*                               WB stage                    */

always @(posedge clk1)
        begin 
            if(Branch_Taken == 0)

            case(MEM_WB_type)
                //rd
                RR_ALU: R[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUout;
                //rt
                RM_ALU: R[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUout;
                //rt
                LOAD: R[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD;

                HALT: HALTED<= #2 1'b1;
            endcase 
        end

endmodule