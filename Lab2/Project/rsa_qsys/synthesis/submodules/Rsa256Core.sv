module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d, // private key
	input  [255:0] i_n,
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished
);
// operations for RSA256 decryption
// namely, the Montgomery algorithm
parameter IDLE=3'd0;
parameter PREP=3'd1;
parameter MONT=3'd2;
parameter MONT_DEVIDE2=3'd3;
parameter CALC=3'd4;




logic [2:0] state,state_nxt;
logic [255:0] m,m_nxt;
logic [255:0] t,t_nxt;
logic [255:0] y,y_nxt;
logic         finished,finished_nxt;
//PREP
logic [256:0] prep_a;
logic [257:0] prep_m_plus_prep_t;
logic [257:0] prep_t_plus_prep_t;
logic [257:0] prep_m,prep_m_nxt;
logic [257:0] prep_t,prep_t_nxt;
logic [8:0]  prep_count,prep_count_nxt;
//MONT
logic [257:0] mont_1_a,mont_1_a_nxt;
logic [257:0] mont_2_a,mont_2_a_nxt;
logic [257:0] mont_1_b,mont_1_b_nxt;
logic [257:0] mont_2_b,mont_2_b_nxt;
logic [257:0] mont_1_m,mont_1_m_nxt;
logic [257:0] mont_2_m,mont_2_m_nxt;
logic [257:0] mont_1_m_minus_n;
logic [257:0] mont_2_m_minus_n;
logic [257:0] mont_1_m_temp;
logic [257:0] mont_2_m_temp;
logic [257:0] mont_1_m_plus_b;
logic [257:0] mont_2_m_plus_b;
logic [8:0]  mont_count,mont_count_nxt;
//CALC
logic [8:0]  calc_count,calc_count_nxt;

assign 	o_a_pow_d=m;
assign  o_finished=finished;
always_comb
begin
	case(state)
		IDLE:
		begin
			if(i_start)
			begin
				state_nxt=PREP;
			end
			else
			begin
				state_nxt=IDLE;
			end
		end
		PREP:
		begin
			if(prep_count==9'd257)
			begin
				state_nxt=MONT;
			end
			else
			begin
				state_nxt=PREP;
			end
		end
		MONT:
		begin
			if(mont_count==9'd255)
			begin
				state_nxt=MONT_DEVIDE2;
			end
			else
			begin
				state_nxt=MONT;
			end
		end
		MONT_DEVIDE2:
		begin
			state_nxt=CALC;
		end
		CALC:
		begin
			if(calc_count==9'd255)
			begin
				state_nxt=IDLE;
			end
			else
			begin
				state_nxt=MONT;
			end
		end
		default
		begin
			state_nxt=IDLE;
		end

		
	endcase
end

always_ff@(posedge i_clk)
begin
	if(i_rst)
	begin
		state<=IDLE;
	end
	else
	begin
		state<=state_nxt;
	end
end

always_comb
begin
	//output
	finished_nxt=0;
	y_nxt=y;

	//PREP
	prep_count_nxt=prep_count;
	prep_t_nxt=prep_t;
	prep_m_nxt=prep_m;
	prep_m_plus_prep_t=prep_m+prep_t;
	prep_t_plus_prep_t=prep_t+prep_t;
	t_nxt=t;
	prep_a={1'd1,256'd0};
	//MONT
	mont_1_a_nxt=mont_1_a;
	mont_1_b_nxt=mont_1_b;
	mont_2_a_nxt=mont_2_a;
	mont_2_b_nxt=mont_2_b;
	mont_1_m_nxt=mont_1_m;
	mont_2_m_nxt=mont_2_m;	
	mont_1_m_minus_n=mont_1_m-{2'd0,i_n};
	mont_2_m_minus_n=mont_2_m-{2'd0,i_n};
	mont_1_m_plus_b=mont_1_m+mont_1_b;
	mont_2_m_plus_b=mont_2_m+mont_2_b;
	mont_1_m_temp=mont_1_m;
	mont_2_m_temp=mont_2_m;
	mont_count_nxt=mont_count;
	//CALC
	calc_count_nxt=calc_count;
	m_nxt=m;

	case(state)
		IDLE:
		begin
		end
		PREP:
		begin
			prep_count_nxt=prep_count+1;
			t_nxt=prep_m;
			mont_1_a_nxt=258'd1;
			mont_1_b_nxt=prep_m;
			mont_2_a_nxt=prep_m;
			mont_2_b_nxt=prep_m;			
			if(prep_a[prep_count])
			begin
				if(prep_m_plus_prep_t>=i_n)
				begin
					prep_m_nxt=prep_m_plus_prep_t-i_n;
				end
				else
				begin
					prep_m_nxt=prep_m_plus_prep_t;
				end
			end
			else
			begin
				prep_m_nxt=prep_m;
			end
			if(prep_t_plus_prep_t>i_n)
			begin
				prep_t_nxt=prep_t_plus_prep_t-i_n;
			end
			else
			begin
				prep_t_nxt=prep_t_plus_prep_t;
			end
			
		end
		MONT:
		begin
			mont_count_nxt=mont_count+1;
			//mont1
			//mont_1_m_nxt=mont_1_m_temp>>1;
			if(mont_1_a[mont_count])
			begin
				if(mont_1_m_plus_b[0])
				begin
					mont_1_m_nxt=(mont_1_m_plus_b+i_n)>>1;
					//mont_1_m_temp=mont_1_m_plus_b+i_n;
				end
				else
				begin
					mont_1_m_nxt=(mont_1_m_plus_b)>>1;
					//mont_1_m_temp=mont_1_m_plus_b;
				end
			end
			else
			begin
				if(mont_1_m[0])
				begin
					mont_1_m_nxt=(mont_1_m+i_n)>>1;
					//mont_1_m_temp=mont_1_m+i_n;
				end
				else
				begin
					mont_1_m_nxt=(mont_1_m)>>1;
					//mont_1_m_temp=mont_1_m;
				end				
			end
			//mont2
			//mont_2_m_nxt=mont_2_m_temp>>1;
			if(mont_2_a[mont_count])
			begin
				if(mont_2_m_plus_b[0])
				begin
					mont_2_m_nxt=(mont_2_m_plus_b+i_n)>>1;
					//mont_2_m_temp=mont_2_m_plus_b+i_n;
				end
				else
				begin
					mont_2_m_nxt=(mont_2_m_plus_b)>>1;
					//mont_2_m_temp=mont_2_m_plus_b;
				end
			end
			else
			begin
				if(mont_2_m[0])
				begin
					mont_2_m_nxt=(mont_2_m+i_n)>>1;
					//mont_2_m_temp=mont_2_m+i_n;
				end
				else
				begin
					mont_2_m_nxt=(mont_2_m)>>1;
					//mont_2_m_temp=mont_2_m;
				end				
			end				
		end
		MONT_DEVIDE2:
		begin
			//mont1
			if(mont_1_m>=i_n)
			begin
				mont_1_m_nxt=mont_1_m_minus_n;
			end
			else
			begin
				mont_1_m_nxt=mont_1_m;
			end
			//mont2
			if(mont_2_m>=i_n)
			begin
				mont_2_m_nxt=mont_2_m_minus_n;
			end
			else
			begin
				mont_2_m_nxt=mont_2_m;
			end				
		end		
		CALC:
		begin
			calc_count_nxt=calc_count+1;
			mont_2_a_nxt=mont_2_m;
			mont_1_b_nxt=mont_2_m;				
			mont_2_b_nxt=mont_2_m;			
			mont_1_m_nxt=258'd0;
			mont_2_m_nxt=258'd0;
			mont_count_nxt=9'd0;
			t_nxt=mont_2_m[255:0];
			if(calc_count==9'd255)
			begin
				finished_nxt=1'd1;
			end
			else
			begin
				finished_nxt=1'd0;
			end
			if(i_d[calc_count])
			begin
				m_nxt=mont_1_m[255:0];
				mont_1_a_nxt=mont_1_m;
				
			end
			else
			begin
				m_nxt=m;
				mont_1_a_nxt=mont_1_a;
			end
		end

	endcase
end

always_ff@(posedge i_clk)
begin
	if(i_rst)
	begin
		//PREP
		y<=i_a;
		prep_m<=258'd0;
		prep_t<={2'd0,i_a};
		prep_count<=9'd0;
		m<=256'd1;
		t<=256'd0;
		//MONT
		mont_1_a<=258'd0;
		mont_1_b<=258'd0;
		mont_1_m<=258'd0;
		mont_2_a<=258'd0;
		mont_2_b<=258'd0;
		mont_2_m<=258'd0;		
		mont_count<=9'd0;
		//CALC
		calc_count<=9'd0;
		finished<=1'd0;
	end
	else if(i_start)
	begin
		y<=i_a;
		prep_m<=258'd0;
		prep_t<={2'd0,i_a};
		prep_count<=9'd0;
		m<=256'd1;
		t<=256'd0;
		//MONT
		mont_1_a<=258'd0;
		mont_1_b<=258'd0;
		mont_1_m<=258'd0;
		mont_2_a<=258'd0;
		mont_2_b<=258'd0;
		mont_2_m<=258'd0;		
		mont_count<=9'd0;
		//CALC
		calc_count<=9'd0;
		finished<=1'd0;		
	end
	else
	begin
		y<=y_nxt;
		//PREP
		prep_m<=prep_m_nxt;
		prep_t<=prep_t_nxt;
		prep_count<=prep_count_nxt;
		m<=m_nxt;
		t<=t_nxt;
		//MONT
		mont_1_a<=mont_1_a_nxt;
		mont_1_b<=mont_1_b_nxt;
		mont_1_m<=mont_1_m_nxt;		
		mont_2_a<=mont_2_a_nxt;
		mont_2_b<=mont_2_b_nxt;
		mont_2_m<=mont_2_m_nxt;			
		mont_count<=mont_count_nxt;
		//CALC
		calc_count<=calc_count_nxt;
		finished<=finished_nxt;		
	end
	
end




endmodule
