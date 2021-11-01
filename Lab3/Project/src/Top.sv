module Top (
	input i_rst_n,
	input i_clk,
	input i_key_0,			// record/pause
	input i_key_1,			// play/pause
	input i_key_2,			// stop

	input [3:0] i_speed,	// speed (0~8)
	input i_fast,			// fast/slow
	input i_inte,			// 1/0 interpolation

	
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	output [15:0] 	o_sev,

	// LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	output [25:0]	o_volume

);

// === params ===
parameter S_IDLE       = 0;
parameter S_I2C        = 1;
parameter S_RECD       = 2;
parameter S_RECD_PAUSE = 3;
parameter S_PLAY       = 4;
parameter S_PLAY_PAUSE = 5;
parameter S_WAIT       = 6;

localparam VOLUME_DROP = 16'b1 << 14;
localparam VOLUME_BAR  = 56'b11111111111111111111111111000000000000000000000000000000;
 
// === variables ===
logic [19:0] address_end, address_end_nxt;
logic [2:0] 	state_r, state_w;
logic [2:0]		speed_r, speed_w;

logic [15:0]	cnt_r, cnt_w;
logic [4:0]		max_r, max_w;

logic signed [15:0] 	volume_data;
logic [15:0] 	volume;

// === output assignments ===
logic i2c_oen, i2c_sdat;
logic [19:0] 	addr_record, addr_play;
logic [15:0] 	data_record, data_play, dac_data;

assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

assign o_SRAM_ADDR = (state_r == S_RECD || state_r == S_RECD_PAUSE) ? addr_record : addr_play[19:0];
assign io_SRAM_DQ  = (state_r == S_RECD || state_r == S_RECD_PAUSE) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state_r == S_RECD || state_r == S_RECD_PAUSE) ? 16'd0 : io_SRAM_DQ; // sram_dq as input
assign volume_data = ( state_r != S_PLAY ) ? data_record : dac_data;
assign volume = ( volume_data >= 0 ) ?  volume_data : (-volume_data);

assign o_SRAM_WE_N = (state_r == S_RECD || state_r == S_RECD_PAUSE) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;


// === submodule i/o ===

logic i2c_finished;

// recorder //
logic record_finish;
logic record_start, record_pause, record_stop;

// player //
logic en_player;

// dsp //
logic dsp_start, dsp_pause, dsp_stop;
logic [ 2:0] speed;
// seven decoder
logic [3:0] sev0, sev1, sev2, sev3;
assign sev0 = {3'd0,test};
assign sev1 = {3'd0,i_clk};
assign sev2 = {3'd0,i_AUD_BCLK};
assign sev3 = {1'd0,state_r};
assign o_sev = { sev0, sev1, sev2, sev3 };

assign o_volume = VOLUME_BAR[max_r+:25];
logic test;

// below is a simple example for module division
// you can design these as you like

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(1),
	.o_finished(i2c_finished),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk),
	.i_start(dsp_start),
	.i_pause(dsp_pause),
	.i_stop(dsp_stop),
	.i_speed(speed),
	.i_fast(i_fast),
	.i_inte(i_inte),
	.i_daclrck(i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.o_dac_data(dac_data),
	.o_sram_addr(addr_play),
	.o_player_en(en_player)
);

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(i_rst_n),
	.i_bclk(i_AUD_BCLK),
	.i_daclrck(i_AUD_DACLRCK),
	.i_en(en_player), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n(i_rst_n), 
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(record_start),
	.i_pause(record_pause),
	.i_stop(record_stop),
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_data(data_record),
	.o_finished(record_finish)
);



assign speed = ( i_speed >= 1 && i_speed <= 8 ) ? i_speed-1 : 0;

always_comb begin
	cnt_w = (cnt_r >= VOLUME_DROP) ? 0 : cnt_r + 1;
	if ( volume[14:10] > max_r ) max_w = volume[14:10];
	else if (cnt_r >= VOLUME_DROP && max_r > 0) max_w = max_r - 1;
	else max_w = max_r;
end

always_comb begin
	test = 0;
	record_start = 0;
	record_pause = 0;
	record_stop  = 0;
	dsp_start    = 0;
	dsp_pause    = 0;
	dsp_stop     = 0;

	state_w = state_r;
	address_end_nxt = address_end;

	case(state_r)
		S_I2C:begin
			if(i2c_finished)
				state_w = S_IDLE;
		end
		S_IDLE:begin
			test = 1;
			if(i_key_0) begin 	   // start record
				state_w = S_RECD;
				address_end_nxt = 0;
			end    	
		end
		S_RECD:begin
			record_start = 1;
			address_end_nxt = addr_record;
			if(i_key_1)begin
				state_w = S_RECD_PAUSE;
			end
		end
		S_RECD_PAUSE:begin
			record_pause = 1;
			if(i_key_1)begin
				state_w = S_RECD;
			end
		end
		S_WAIT:begin
			if(i_key_0)begin // start playing
				state_w = S_PLAY;
			end
		end
		S_PLAY:begin
			dsp_start = 1;
			if(i_key_1)begin
				state_w = S_PLAY_PAUSE;
			end
		end
		S_PLAY_PAUSE:begin
			dsp_pause = 1;
			if(i_key_1)begin
				state_w = S_PLAY;
			end
		end
	endcase

	// stop process
	case(state_r)
		S_RECD, S_RECD_PAUSE:begin
			if(i_key_2 || record_finish)begin
				state_w = S_WAIT;
				record_stop = 1;
			end
		end
		S_PLAY, S_PLAY_PAUSE:begin
			if(i_key_2 || speed + addr_play >= address_end)begin
				state_w = S_WAIT;
				dsp_stop = 1;
			end
		end
	endcase
end

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r 	<= S_I2C;
		address_end <= 0;
		speed_r 	<= 0;
		cnt_r 		<= 0;
		max_r		<= 0;
	end
	else begin
		state_r 	<= state_w;
		address_end <= address_end_nxt;
		speed_r 	<= speed_w;
		cnt_r		<= cnt_w;
		max_r		<= max_w;
	end
end

endmodule


module I2cInitializer(
	input  i_rst_n,
    input  i_clk,
    input  i_start,
    output o_finished, 
    output o_sclk,    
    output o_sdat,    
    output o_oen     // you are outputing (you are not outputing only when you are "ack"ing.)
);

logic [23:0] INIT_DATA[6:0];

assign INIT_DATA[0] = 24'b0011_0100_000_1111_0_0000_0000;
assign INIT_DATA[1] = 24'b0011_0100_000_0100_0_0001_0101;
assign INIT_DATA[2] = 24'b0011_0100_000_0101_0_0000_0000;
assign INIT_DATA[3] = 24'b0011_0100_000_0110_0_0000_0000;
assign INIT_DATA[4] = 24'b0011_0100_000_0111_0_0100_0010;
assign INIT_DATA[5] = 24'b0011_0100_000_1000_0_0001_1001;
assign INIT_DATA[6] = 24'b0011_0100_000_1001_0_0000_0001;

parameter IDLE    = 3'd0;
parameter PREPARE = 3'd1;
parameter SEND    = 3'd2;
parameter CHECK   = 3'd3;
parameter FINISH  = 3'd4;

logic     hi, hi2;
logic       finished, finished_nxt;
logic       acknowledge;
logic       sclk, sclk_nxt;
logic       sdat, sdat_nxt;
logic       oen, oen_nxt;
logic [2:0] state, state_nxt;
logic [2:0] data_counter, data_counter_nxt;
logic [4:0] bit_counter, bit_counter_nxt;

assign o_sclk = sclk;
assign o_sdat = o_oen ? sdat : 1'bz;
assign o_oen  = oen;
assign o_finished = finished;


//=========== Combinential ==========//
assign acknowledge = (bit_counter == 5'd8) || (bit_counter == 5'd16) || (bit_counter == 5'd24);

assign hi = !sclk ? (oen? 1:0 )  :0;

always_comb begin
	state_nxt = state;
	sclk_nxt = sclk;
	sdat_nxt = sdat;
	oen_nxt = oen;
	finished_nxt = 0;
	bit_counter_nxt  = bit_counter;
	data_counter_nxt = data_counter;
	case(state)
		IDLE:begin
			if(i_start)
				state_nxt = PREPARE;
		end
		PREPARE:begin
			sdat_nxt = 0;
			state_nxt = SEND;
		end
		SEND:begin
			sclk_nxt = !sclk;
			if(acknowledge && sclk )begin
				oen_nxt = !oen;
			end
			if(sclk) begin
				sdat_nxt = INIT_DATA[data_counter][5'd23 - bit_counter];
			end
			else if(hi)begin
				bit_counter_nxt = bit_counter + 1;
			end
			if(bit_counter == 5'd24 && sclk && !oen)begin
				data_counter_nxt = data_counter+1;
				bit_counter_nxt = 0;
				sdat_nxt = 0;
				state_nxt = CHECK;
			end
		end
		CHECK:begin
			if(!sclk)
				sclk_nxt = !sclk;
			else begin
				sdat_nxt = 1;
				if(data_counter == 5'd7)
					state_nxt = FINISH;
				else
					state_nxt = PREPARE;
			end
		end
		FINISH:begin
			finished_nxt = 1;
		end
	endcase
end


//=========== Sequential ============//
always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state <= IDLE;
		sdat  <= 1;
		sclk  <= 1;
		oen   <= 1;
		finished     <= 0;
		data_counter <= 0;
		bit_counter  <= 0;
	end
	else begin
		state <= state_nxt;
		sdat  <= sdat_nxt;
		sclk  <= sclk_nxt;
		oen   <= oen_nxt;
		finished     <= finished_nxt;
		data_counter <= data_counter_nxt;
		bit_counter  <= bit_counter_nxt;
	end
end

endmodule

// record left channel
module AudRecorder(
    input         i_rst_n, 
	input         i_clk,
	input         i_lrc,
	input         i_start,
	input         i_pause,
	input         i_stop,
	input         i_data,
	output [19:0] o_address,
	output [15:0] o_data,
    output        o_finished
);

localparam IDLE   = 3'd0;
localparam WAIT_L = 3'd1;
localparam WAIT_R = 3'd2;
localparam READ   = 3'd3; 
localparam SAVE   = 3'd4;


//========  variables =========//
logic [ 2:0] state, state_nxt;
logic [ 3:0] counter, counter_nxt;
logic [19:0] address, address_nxt;
logic [15:0] data, data_nxt;

//======== ouput ==========//
assign o_data     = data;
assign o_address  = address;
assign o_finished = ((state == SAVE && &address) || i_stop) ? 1 : 0;
//======== FSM ============//
always_comb begin
    state_nxt = state;
    case(state)
        IDLE:begin
            if(i_start) begin
                state_nxt = i_lrc ? WAIT_R : WAIT_L;
            end
        end
        WAIT_L:begin
            if(i_lrc) 
                state_nxt = WAIT_R;
        end
        WAIT_R:begin
            if(!i_lrc) 
                state_nxt = READ;
        end
        READ:begin
            if(counter == 15)
                state_nxt = SAVE;
        end
        SAVE:begin
            state_nxt = WAIT_L;
        end
    endcase 
    
    if(i_pause || i_stop) 
        state_nxt = IDLE;
end

//============= combinential =================//
always_comb begin
    data_nxt = data;
    address_nxt = address;
    counter_nxt = counter; 
    case(state)
        WAIT_R:begin
            counter_nxt = 0;
        end
        READ:begin
            data_nxt = { data[14:0], i_data};
            counter_nxt = counter + 1;
        end
        SAVE:begin
            address_nxt = address + 1;
        end
    endcase 
end

//============ sequential ================//
always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state   <= IDLE;
        data    <= 0;
        counter <= 0;
        address <= 0;
	end
	else begin
		state   <= state_nxt;
        data    <= data_nxt;
        address <= address_nxt;
        counter <= counter_nxt;
	end
end


endmodule

// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
module AudPlayer(
	input           i_rst_n,
	input           i_bclk,
	input           i_daclrck,
	input           i_en, // enable AudPlayer only when playing audio, work with AudDSP
	input [15:0]    i_dac_data, //dac_data
	output          o_aud_dacdat
);

// === params ===
localparam S_WAIT = 1;
localparam S_SEND = 0;

// === variables ===
logic [1:0]		state_r, state_w;
logic [15:0]	data_r, data_w;
logic [3:0]		cnt_r, cnt_w;
logic 			lrc_r;

// === output assignment ===
assign o_aud_dacdat = ( state_r == S_SEND ) ? data_r[cnt_r] : 0;

// === combinational ===

always_comb begin

	// default values
	state_w = state_r; 
	data_w = data_r;
	cnt_w = cnt_r;

	if ( i_en ) begin
		case(state_r)
			S_WAIT: begin		// wait for lrc to rise
				if ( i_daclrck != lrc_r ) begin
					state_w = S_SEND;
					data_w = ( i_daclrck ) ? data_r : i_dac_data;
					cnt_w = 15;
				end
			end
			S_SEND: begin
				state_w = (cnt_r == 0) ? S_WAIT : state_w;
				cnt_w = (cnt_r == 0) ? 15 : cnt_r - 1;
			end
		endcase
	end else begin
		state_w = S_WAIT;
	end
end

// === sequential ===

always_ff @(posedge i_bclk or negedge i_rst_n) begin
	if ( !i_rst_n ) begin
		cnt_r <= 0;
		data_r <= 0;
		lrc_r <= 0;
		state_r <= S_WAIT;
	end else begin
		cnt_r <= cnt_w;
		data_r <= data_w;
		state_r <= state_w;
		lrc_r <= i_daclrck;
	end
end

endmodule

module AudDSP(
    input           i_rst_n,
    input           i_clk,
    input           i_start,		// start or resume playing 
    input           i_pause,		// pause
    input           i_stop,			// stop
    input [2:0]     i_speed,		// 0~7 (represent 1~8)
    input           i_fast,			// 1 -> fast, 0 -> slow
    input           i_inte,			// 1 or 0 order interpolation
    input           i_daclrck,		
    input signed [15:0] i_sram_data,	// the 16-bit data stored in sram
	output [15:0]	o_dac_data,		// AudPlayer will send this data to wm8731
	output [19:0]	o_sram_addr,	// sram address
    output          o_player_en		// enable AudPlayer
);

parameter IDLE=3'd0;
parameter PREPARE=3'd1;
parameter FAST=3'd2;
parameter SLOW=3'd3;
parameter WAIT=3'd4;

//state
logic [2:0] state, state_nxt;
//output
logic signed [15:0] dac_data,dac_data_nxt;
logic [19:0] sram_addr,sram_addr_nxt;
logic        player_en,player_en_nxt;
//reg
logic signed [15:0] previous_dac_data,previous_dac_data_nxt;
logic [3:0]  slow_count,slow_count_nxt;

assign o_dac_data=dac_data;
assign o_sram_addr=sram_addr;
assign o_player_en=player_en;

always_comb
begin
	case(state)
		IDLE:
		begin
			if(i_start)
			begin
				state_nxt=PREPARE;
			end
			else
			begin
				state_nxt=IDLE;
			end
		end
		PREPARE:
		begin
			if( i_pause || i_stop )
			begin
				state_nxt=IDLE;
			end
			else if(i_daclrck)
			begin
				if(i_fast)
				begin
					state_nxt=FAST;
				end
				else
				begin
					state_nxt=SLOW;
				end
			end
			else
			begin
				state_nxt=state;
			end
		end
		FAST:
		begin
			if( i_pause || i_stop )
			begin
				state_nxt=IDLE;
			end
			else
			begin
				state_nxt=WAIT;
			end		
		end
		SLOW:
		begin
			if( i_pause || i_stop )
			begin
				state_nxt=IDLE;
			end
			begin
				state_nxt=WAIT;
			end		
		end
		WAIT:
		begin
			if( i_pause || i_stop )
			begin
				state_nxt=IDLE;
			end
			else if(!i_daclrck)
			begin
				state_nxt=PREPARE;
			end
			else
			begin
				state_nxt=WAIT;
			end		
		end
		default:
		begin
			state_nxt=IDLE;
		end
	endcase
end


always_ff@(posedge i_clk or negedge i_rst_n)
begin
	if(!i_rst_n)
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
	sram_addr_nxt=sram_addr;
	dac_data_nxt=dac_data;
	previous_dac_data_nxt=previous_dac_data;
	slow_count_nxt=slow_count;
	player_en_nxt=player_en;
	case(state)
		IDLE:
		begin
			player_en_nxt=0;
		end
		PREPARE:
		begin
		end
		FAST:
		begin
			sram_addr_nxt=sram_addr+i_speed+1;
			dac_data_nxt=i_sram_data;
			previous_dac_data_nxt=i_sram_data;
		end
		SLOW:
		begin
			if(slow_count<i_speed)
			begin
				slow_count_nxt=slow_count+1;
				sram_addr_nxt=sram_addr;
				previous_dac_data_nxt=previous_dac_data;
				if(i_inte)
				begin
					dac_data_nxt=$signed(previous_dac_data)+($signed(i_sram_data)-$signed(previous_dac_data))*$signed(slow_count+1)/$signed(i_speed+1);
					//dac_data_nxt=$signed($signed(previous_dac_data)*$signed(i_speed-slow_count))+($signed(i_sram_data)*$signed(slow_count+1))/$signed(i_speed+1);
				end
				else
				begin
					dac_data_nxt=previous_dac_data;
				end
			end
			else
			begin
				slow_count_nxt=0;
				sram_addr_nxt=sram_addr+1;
				previous_dac_data_nxt=i_sram_data;
				dac_data_nxt=i_sram_data;
			end
		end
		WAIT:
		begin
			if(!i_daclrck)
			begin
				player_en_nxt=1;
			end
			else
			begin
				player_en_nxt=player_en;
			end
		end
		default:
		begin
		end
	endcase
	
	if(i_stop)
	begin
		sram_addr_nxt=0;
	end
end

always_ff@(posedge i_clk or negedge i_rst_n)
begin
	if(!i_rst_n)
	begin
		sram_addr<=16'd0;
		dac_data<=20'd0;
		previous_dac_data<=16'd0;
		slow_count<=4'd0;
		player_en<=1'd0;
	end
	else
	begin
		sram_addr<=sram_addr_nxt;
		dac_data<=dac_data_nxt;
		previous_dac_data<=previous_dac_data_nxt;
		slow_count<=slow_count_nxt;
		player_en<=player_en_nxt;	
	end
end

endmodule
