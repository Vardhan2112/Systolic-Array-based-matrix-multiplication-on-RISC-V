module ID_EX_FLUSH
(
    input           flush           ,
    input           hit             ,
    input   [5:0]   id_ex_ctrl      ,
    input           EN_NPU          ,
    input           ack             ,

    output  [5:0]   id_ex_f_ctrl
);

    
    assign id_ex_f_ctrl = ((flush && !hit) || EN_NPU || (ack && !EN_NPU)) ? 6'b0 : id_ex_ctrl;
    
endmodule