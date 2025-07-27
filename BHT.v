
module BHT
#(
    parameter           BHT_SIZE = 256      ,   
    parameter           HISTORY_LENGTH = 2  ,   
    parameter   [1:0]   ST = 2'b11          ,
    parameter   [1:0]   wt = 2'b10          ,
    parameter   [1:0]   wn = 2'b01          ,
    parameter   [1:0]   SN = 2'b00
)
(
    input           clk                     ,
    input           rst_i                   ,
    input   [7:0]   bht_addr                ,
    input   [1:0]   bht_init                ,
    
    input           mem_is_taken            ,   
    input           PCSrc                   ,   
    input   [31:0]  b_pc                    ,
    input   [31:0]  mem_pc                  ,

    output          T_NT                    ,   
    output          miss_predict              
);  
    /******************* for simulation *************************/

    generate
        genvar  idx;
        for (idx = 0; idx < 256; idx = idx+1) begin: history_table
            wire [1:0] t_state;
            assign t_state = bht[idx];
        end
    endgenerate

    /********************** module start *************************/

    reg [HISTORY_LENGTH-1:0] bht [0:BHT_SIZE-1];           

    always @(posedge clk)
    begin                                                      
        if (rst_i) begin
            bht[bht_addr] <= bht_init;
        end
        else begin
            case (bht[mem_pc[9:2]])                            
                SN : begin                                        
                    if (PCSrc) begin                                 
                        bht[mem_pc[9:2]] <= wn;                 
                    end     
                    else begin                                      
                        bht[mem_pc[9:2]] <= SN;                  
                    end
                end

                wn : begin
                    if (PCSrc) begin                                
                        bht[mem_pc[9:2]] <= wt;                 
                    end     
                    else begin
                        bht[mem_pc[9:2]] <= SN;                 
                    end
                end

                wt : begin
                    if (bht[mem_pc[9:2]][1] != PCSrc) begin
                        bht[mem_pc[9:2]] <= wn;                     
                    end 
                    else if (mem_is_taken) begin                        // 
                        bht[mem_pc[9:2]] <= ST;
                    end
                end

                ST : begin
                    if (bht[mem_pc[9:2]][1] != PCSrc) begin              
                        bht[mem_pc[9:2]] <= wt;                     
                    end
                    else if (mem_is_taken) begin
                        bht[mem_pc[9:2]] <= ST;
                    end
                end

                default : bht[mem_pc[9:2]] = 2'b0;
            endcase
        end
    end 

    reg miss_predict_r;
    always @ (mem_pc or PCSrc) begin
        miss_predict_r = 1'b0;
        if (bht[mem_pc[9:2]][1] != PCSrc) begin
            miss_predict_r = 1'b1;                              
        end
    end
    assign miss_predict = miss_predict_r;

 
    assign T_NT = ((PCSrc && !mem_is_taken) || miss_predict) ? 1'b1 : bht[b_pc[9:2]][1];

endmodule
