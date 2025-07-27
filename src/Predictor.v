module PREDICTOR
(   
    input   [6:0]   opcode          ,
    input   [31:0]  pc              ,  
    
    output          is_branch       ,  
    output  [31:0]  b_pc            
);
    
    // Predictor FSM
    
    // Output taken
    assign is_branch = (opcode == 7'b1100011) ? 1'b1 : 1'b0;       
    assign b_pc = is_branch ? pc : 32'b0;                         

endmodule