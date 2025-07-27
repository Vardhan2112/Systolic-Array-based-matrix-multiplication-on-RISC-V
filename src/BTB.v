
module BTB 
#(
  parameter NUM_ENTRIES = 256  ,  
  parameter ENTRY_WIDTH = 40     
)
(
  input           clk         ,
  input           rst_i       ,
  input   [7:0]   btb_addr    ,
  input   [39:0]  btb_init    ,

  input           is_branch   ,   
  input   [31:0]  pc          ,  
  input   [31:0]  mem_pc      ,   
  input   [31:0]  target      ,  
  input           is_taken    ,   
  input           PCSrc       ,
  input           miss_predict,
  
  output          hit         ,
  output  [31:0]  next_pc         
);

  generate
    genvar 		 idx;
    for(idx = 0; idx < 256; idx = idx+1) begin: btb_target
	    wire [39:0] tmp;
	    assign tmp = btb[idx];
    end
  endgenerate

  reg [ENTRY_WIDTH-1:0] btb [NUM_ENTRIES-1:0];
  reg   [31:0]  next_pc_r;
  reg           hit_r;
  
  always @ (posedge clk)
  begin
    if (rst_i) begin
      btb[btb_addr] <= btb_init;
    end
    else 
    if (is_taken && PCSrc) begin                
      btb[mem_pc[9:2]] <= {mem_pc[9:2], target};
    end
  end

  always @ (miss_predict or is_branch or PCSrc or is_taken or pc or mem_pc or target)
  begin
    hit_r = 1'b0;
    next_pc_r = 32'b0;
    if (is_taken && PCSrc) begin                
      next_pc_r = target;
    end
    else
    if(miss_predict) begin
      next_pc_r = mem_pc + 32'd4;
    end
    else if(is_branch && !PCSrc) begin
      if (is_taken) begin                                    
        next_pc_r = btb[pc[9:2]][31:0]; 
        hit_r = 1'b1;                             
      end
    end
     else begin
      next_pc_r = 32'b0;
    end 
  end

  reg [9:0] cnt;
  reg [9:0] h_cnt;
  always @ (posedge clk) begin
    if (rst_i) 
      cnt <= 10'b0;
    else if (is_branch)
      cnt <= cnt + 10'b1;
  end

  always @ (posedge clk) begin
    if (rst_i) 
      h_cnt <= 10'b0;
    else if (hit_r)
      h_cnt <= h_cnt + 10'b1;
  end

  assign hit = hit_r;
  assign next_pc = next_pc_r;

endmodule