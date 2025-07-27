module ID_STAGE
(   
    input           clk_50          ,
    input           rst             ,
    input   [4:0]   reg_addr        ,
    input   [31:0]  reg_init        ,

    input   [31:0]  INST            ,
    input   [4:0]   WR              ,
    input   [4:0]   RD              ,
    input   [31:0]  WD              ,
    input           RegWrite        ,
    input           MEMRead         ,
    input           flush           ,
    input           hit             ,
    input           ack             ,
    input   [9:0]   mem_wr_addr     ,
    input           mem_wr_en       ,
        
    output          stall           ,
    output          double_matr     ,   // detection of double matrix(NPU is already ON)
    output  [31:0]  RD1             ,
    output  [31:0]  RD2             ,
    output  [31:0]  S_INST          ,
    output  [5:0]   f_id_ctrl       ,
    output  [3:0]   ALU_control     ,
    output          EN_NPU          ,
    output  [9:0]   matA_addr       ,   // pass matrix starting addrs to NPU
    output  [9:0]   matB_addr       ,
    output  [9:0]   matC_addr                
);  
    wire            WE;
    wire    [7:0]   control;
    wire            critical;
    wire            npu_stalling1;     
    wire            npu_stalling2;      
    wire            npu_stalling3;      
    wire    [31:0]  RD3;
    reg     [9:0]   critical_addr;      
    reg     [4:0]   npu_reg_addr;       
    reg     [9:0]   matA_addr;
    reg     [9:0]   matB_addr;
    reg     [9:0]   matC_addr;
    reg             double_matr_r = 0;
    reg             EN_NPU = 0;         
    reg             npu_stall = 0;      
                                        
    always @(posedge clk_50 or posedge rst) begin
        if(rst) begin   
            EN_NPU <= 1'b0;
            critical_addr <= 0;
            double_matr_r <= 0;
            npu_reg_addr <= 0;
            matA_addr <= 0;
            matB_addr <= 0;
            matC_addr <= 0;
        end
        else if(ack) begin                              // when NPU finishes its operation
            EN_NPU <= 1'b0;
            critical_addr <= 0;
            npu_stall <= 0;
            double_matr_r <= 0;
            npu_reg_addr <= 0;
            matA_addr <= 0;
            matB_addr <= 0;
            matC_addr <= 0;
        end
        else if(ALU_control == 4'd8) begin              
            if(EN_NPU) begin
                double_matr_r <= 1;
            end
            else begin
                EN_NPU <= 1'b1;
                npu_stall <= 1'b1;
            end
        end
        else if(critical) begin                         
            npu_stall <= 1'b1;
        end
        else if(!critical && critical_addr) begin       
            npu_stall <= 1'b0;
        end
        else if(npu_stalling2 && EN_NPU) begin         
            critical_addr <= RD1[9:0];                  
        end
        else begin
        end

       
        if(npu_stalling3) begin                                     
            matC_addr <= RD3;
        end
        else if(npu_stalling2) begin                                     
            matB_addr <= RD3;
            npu_reg_addr <= INST[11:7];                             
        end
        else if(npu_stalling1) begin
            matA_addr <= RD3;
            npu_reg_addr <= INST[19:15];                            
        end
        else if(npu_stall) begin
            npu_reg_addr <= INST[24:20];                            
        end
        else begin
            npu_reg_addr <= 0; 
        end
    end
    assign double_matr = double_matr_r;

    HAZARD_DETECTION HAZARD_DETECTION
    (   
        //INPUT
        .MEMRead(MEMRead)                   ,
        .RD(RD)                             ,
        .RS1(INST[19:15])                   ,
        .RS2(INST[24:20])                   ,
        .mat_start(npu_stall || double_matr),
        .EN_NPU(EN_NPU)                     ,
        .mem_wr(mem_wr_en)                  ,
        .critical_addr(critical_addr)       ,
        .mem_is_writing(mem_wr_addr)        ,
        
        //OUTPUT
        .stall(stall)                       ,
        .critical(critical)
    );

    CONTROL CONTROL
    (
        //INPUT
        .CtrlSrc(stall)             ,
        .opcode(INST[6:0])          ,
        
        //OUTPUT
        .control(control)
    );

    REGISTER #(1) calc_addr_1
    (
        .CLK(clk_50)        ,
        .RST(rst)           ,
        .EN(1'b0)           ,
        .D(npu_stall)       ,
        .Q(npu_stalling1)
    );

    REGISTER #(1) calc_addr_2
    (
        .CLK(clk_50)        ,
        .RST(rst)           ,
        .EN(1'b0)           ,
        .D(npu_stalling1)   ,
        .Q(npu_stalling2)
    );

    REGISTER #(1) calc_addr_3
    (
        .CLK(clk_50)        ,
        .RST(rst)           ,
        .EN(1'b0)           ,
        .D(npu_stalling2)   ,
        .Q(npu_stalling3)
    );

    //assign WE = npu_stall ? 1'b0 : RegWrite;
    REGISTER_FILE REGISTER_FILE
    (
        //INPUT
        .clk_50(clk_50)             ,
        .rst(rst)                   ,
        .reg_addr(reg_addr)         ,
        .reg_init(reg_init)         ,
        
        .RR1(INST[19:15])           ,
        .RR2(INST[24:20])           ,
        .RR3(npu_reg_addr)          ,
        .WR(WR)                     ,
        .WD(WD)                     ,
        .WE(RegWrite)               ,
        
        //OUTPUT
        .RD1(RD1)                   ,
        .RD2(RD2)                   ,
        .RD3(RD3)
    );

    IMMGEN IMMGEN
    (
        //INPUT
        .INST(INST)                 ,    
       
        //OUTPUT
        .S_INST(S_INST)
    );

    ALU_CONTROL ALU_CONTROL
    (
        //INPUT
        .funct7({INST[30],INST[25]}), 
        .funct3(INST[14:12])        , 
        .ALUOp(control[1:0])        , 
        
        //OUTPUT
        .ALU_control(ALU_control)
    );

    ID_EX_FLUSH ID_EX_FLUSH
    (
        //INPUT
        .flush(flush)               ,
        .hit(hit)                   ,
        .id_ex_ctrl(control[7:2])   ,
        .EN_NPU(EN_NPU)             ,
        .ack(ack)                   ,
       
        //OUTPUT
        .id_ex_f_ctrl(f_id_ctrl)    
    );
    
endmodule