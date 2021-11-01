module multDiv(
    clk,
    rst_n,
    valid,
    ready,
    mode,
    in_A,
    in_B,
    out
);

    // Definition of ports
    input         clk, rst_n;
    input         valid, mode; // mode: 0: multu, 1: divu
    output        ready;
    input  [31:0] in_A, in_B;
    output [63:0] out;

    // Definition of states
    parameter IDLE = 2'b00;
    parameter MULT = 2'b01;
    parameter DIV  = 2'b10;
    parameter OUT  = 2'b11;

    // Todo: Wire and reg
    reg  [ 1:0] state, state_nxt;
    reg  [ 4:0] counter, counter_nxt;
    reg  [63:0] shreg, shreg_nxt;
    reg  [31:0] alu_in, alu_in_nxt;
    reg  [32:0] alu_out;

    // Todo 5: wire assignments
    assign ready=(state==OUT)?1'b1:1'b0;
    assign out=(ready==1'b1)?shreg:64'd0;
    // Combinational always block
    // Todo 1: State machine
    always @(*) begin
        case(state)
            IDLE:begin
	    if(valid==1'b0)
		state_nxt=IDLE;
	    else
		if(mode==1'b0)
		    state_nxt=MULT;
		else
		    state_nxt=DIV;
            end
            MULT:begin
	    if(counter==5'b11111)
		state_nxt=OUT;
	    else
		state_nxt=MULT; 
	    end
            DIV:begin
	    if(counter==5'b11111)
		state_nxt=OUT;
	    else
		state_nxt=DIV;
	    end
            OUT: begin
		state_nxt = IDLE;
	    end
        endcase
    end
    // Todo 2: Counter
    always @(*) begin
    	case(state)
	    IDLE: counter_nxt=0;
	    OUT: counter_nxt=0;
	    MULT: counter_nxt=counter+1;
	    DIV: counter_nxt=counter+1;
	    default:counter_nxt=0;
	endcase
    end
    // ALU input
    always @(*) begin
        case(state)
            IDLE: begin
                if (valid) alu_in_nxt = in_B;
                else       alu_in_nxt = 0;
            end
            OUT : alu_in_nxt = 0;
            default: alu_in_nxt = alu_in;
        endcase
    end

    // Todo 3: ALU output
    always @(*) begin
	case(state)
	    IDLE:alu_out=32'd0;
	    OUT:alu_out=32'd0;
	    MULT:begin
		if(shreg[0]==1'b0) alu_out=shreg[63:32];
		else 		 alu_out=shreg[63:32]+alu_in;
	    end
	    DIV:begin
		alu_out=shreg[63:32]-alu_in;
	    end
	endcase
    end
    // Todo 4: Shift register
    always @(*) begin
	case(state)
	    IDLE:begin
		if(valid) begin
		    if(mode) shreg_nxt={31'd0,in_A,1'd0};
		    else shreg_nxt={32'd0,in_A};
		end
		else shreg_nxt=shreg;
	    end
	    OUT: shreg_nxt=shreg;
	    MULT: begin
		shreg_nxt={1'd0,alu_out,shreg[31:1]};
	    end
	    DIV: begin
		if (counter == 5'd31) begin
                    if (alu_out[31] == 1) shreg_nxt={1'd0,shreg[62:32],shreg[30:0],1'd0};
                    else shreg_nxt={1'd0, alu_out[30:0],shreg[30:0],1'd1};
     		end
                else begin
                    if (alu_out[31] == 1) shreg_nxt={shreg[62:0],1'd0};
                    else shreg_nxt={alu_out[30:0],shreg[31:0],1'd1};
                end
	    end
	endcase
    end
    // Todo: Sequential always block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
	    counter <= 0;
        end
        else begin
            state <= state_nxt;
	    counter <= counter_nxt;
	    shreg <= shreg_nxt;
	    alu_in <= alu_in_nxt;
        end
    end

endmodule
