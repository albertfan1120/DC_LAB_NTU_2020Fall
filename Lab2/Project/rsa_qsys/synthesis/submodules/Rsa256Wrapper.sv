module Rsa256Wrapper (
        input         avm_rst,
        input         avm_clk,
        output  [4:0] avm_address,
        output        avm_read,
        input  [31:0] avm_readdata,
        output        avm_write,
        output [31:0] avm_writedata,
        input         avm_waitrequest
    );

    localparam RX_BASE     = 0*4;
    localparam TX_BASE     = 1*4;
    localparam STATUS_BASE = 2*4;
    localparam TX_OK_BIT   = 6;
    localparam RX_OK_BIT   = 7;

    // Feel free to design your own FSM!
    localparam S_GET_KEY = 0;
    localparam S_GET_DATA = 1;
    localparam S_WAIT_CALCULATE = 2;
    localparam S_SEND_DATA = 3;

    logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
    logic [1:0] state_r, state_w;
    logic [6:0] bytes_counter_r, bytes_counter_w;
    logic [4:0] avm_address_r, avm_address_w;
    logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

    logic rsa_start_r, rsa_start_w;
    logic rsa_finished;
    logic [255:0] rsa_dec;

    assign avm_address = avm_address_r;
    assign avm_read = avm_read_r;
    assign avm_write = avm_write_r;
    assign avm_writedata = dec_r[247-:8];

    Rsa256Core rsa256_core(
        .i_clk(avm_clk),
        .i_rst(avm_rst),
        .i_start(rsa_start_r),
        .i_a(enc_r),
        .i_d(d_r),
        .i_n(n_r),
        .o_a_pow_d(rsa_dec),
        .o_finished(rsa_finished)
    );

    task StartRead;
        input [4:0] addr;
        begin
            avm_read_w = 1;
            avm_write_w = 0;
            avm_address_w = addr;
        end
    endtask
    task StartWrite;
        input [4:0] addr;
        begin
            avm_read_w = 0;
            avm_write_w = 1;
            avm_address_w = addr;
        end
    endtask

    always_comb begin
        d_w = d_r;
        dec_w = dec_r;
        enc_w = enc_r;
        n_w = n_r;
        rsa_start_w = rsa_start_r;
        // TODO

        case(state_r)
            S_GET_KEY: begin
                avm_read_w = 1;
                avm_write_w = 0;
                dec_w = dec_r;
                enc_w = enc_r;
                rsa_start_w = rsa_start_r;

                if(avm_waitrequest == 1'b0) begin
                    if(avm_address_r == RX_BASE) begin
                        n_w = n_r;
                        d_w = d_r;
                        
                        n_w[8*(bytes_counter_r-32)+7 -: 8] = (bytes_counter_r > 7'd31)? avm_readdata[7:0] : n_r[8*(bytes_counter_r-32)+7 -: 8];
                        d_w[8*bytes_counter_r+7 -: 8] = (bytes_counter_r > 7'd31)? d_r[8*bytes_counter_r+7 -: 8] : avm_readdata[7:0];

                        bytes_counter_w = bytes_counter_r - 7'd1; 
                        avm_address_w = STATUS_BASE;
                    end
                    else if(avm_readdata[RX_OK_BIT] == 1'b1) begin
                        n_w = n_r;
                        d_w = d_r;
                        avm_address_w = RX_BASE;
                        bytes_counter_w = bytes_counter_r;
                    end
                    else begin
                        n_w = n_r;
                        d_w = d_r;
                        avm_address_w = avm_address_r;
                        bytes_counter_w = bytes_counter_r;
                    end
                end
                else begin
                    n_w = n_r;
                    d_w = d_r;
                    avm_address_w = avm_address_r;
                    bytes_counter_w = bytes_counter_r;
                end

                if(bytes_counter_w[6] == 1'b1) begin
                    state_w = S_GET_DATA;
                end
                else begin
                    state_w = state_r;
                end
            end
            
            S_GET_DATA: begin
                avm_write_w = 0;
                dec_w = dec_r;
                d_w = d_r;
                n_w = n_r;

                if(avm_waitrequest == 1'b0) begin
                    if(avm_address_r == RX_BASE) begin
                        enc_w = enc_r;
                        enc_w[8*bytes_counter_r+7 -: 8] = avm_readdata[7:0];

                        bytes_counter_w = bytes_counter_r - 7'd1; 
                        avm_address_w = STATUS_BASE;
                    end
                    else if (avm_readdata[RX_OK_BIT] == 1'b1) begin
                        avm_address_w = RX_BASE;
                        enc_w = enc_r;
                        bytes_counter_w = bytes_counter_r;
                    end
                    else begin
                        enc_w = enc_r;
                        avm_address_w = avm_address_r;
                        bytes_counter_w = bytes_counter_r;
                    end
                end
                else begin
                    enc_w = enc_r;
                    avm_address_w = avm_address_r;
                    bytes_counter_w = bytes_counter_r;
                end

                if(bytes_counter_w[6] == 1'b1) begin
                    rsa_start_w = 1'b1;
                    state_w = S_WAIT_CALCULATE;
                    avm_read_w = 1'b0;
                end
                else begin
                    rsa_start_w = 1'b0;
                    state_w = state_r;
                    avm_read_w = avm_read_r;
                end
            end

            S_WAIT_CALCULATE: begin
                rsa_start_w = 1'b0;
                d_w = d_r;
                n_w = n_r;
                enc_w = enc_r;
                bytes_counter_w = bytes_counter_r;
                avm_write_w = avm_write_r;

                if(rsa_finished == 1'b1) begin
                    avm_address_w = STATUS_BASE;
                    state_w = S_SEND_DATA;
                    dec_w = rsa_dec;
                    avm_read_w = 1'b1;
                end
                else begin
                    avm_address_w = avm_address_r;
                    state_w = state_r;
                    avm_read_w = avm_read_r;
                    dec_w = dec_r;
                end
            end

            S_SEND_DATA: begin            
                // receive (write)
                d_w = d_r;
                n_w = n_r;
                enc_w = enc_r;
                rsa_start_w = rsa_start_r;

                if(avm_waitrequest == 1'b0) begin
                    if(avm_address_r == TX_BASE) begin
                        dec_w = dec_r << 8;
                        bytes_counter_w = bytes_counter_r - 7'd1; 
                        avm_address_w = STATUS_BASE;
                        avm_write_w = 1'b0;
                        avm_read_w = 1'b1;
                    end
                    else if(avm_readdata[TX_OK_BIT] == 1'b1) begin
                        avm_address_w = TX_BASE;
                        bytes_counter_w = bytes_counter_r;
                        dec_w = dec_r;
                        avm_write_w = 1'b1;
                        avm_read_w = 1'b0;
                    end
                    else begin
                        dec_w = dec_r;
                        avm_address_w = avm_address_r;
                        bytes_counter_w = bytes_counter_r;
                        avm_read_w = avm_read_r;
                        avm_write_w = avm_write_r;
                    end
                end
                else begin
                    dec_w = dec_r;
                    avm_address_w = avm_address_r;
                    bytes_counter_w = bytes_counter_r;
                    avm_read_w = avm_read_r;
                    avm_write_w = avm_write_r;
                end
                
                if(bytes_counter_w[6] == 1'b1) begin
                    state_w = S_GET_DATA;
                end
                else begin
                    state_w = state_r;
                end
            end 

            default: begin
                d_w = d_r;
                n_w = n_r;
                dec_w = dec_r;
                enc_w = enc_r;
                rsa_start_w = rsa_start_r;
                avm_address_w = avm_address_r;
                bytes_counter_w = bytes_counter_r;
                avm_read_w = avm_read_r;
                avm_write_w = avm_write_r;
                state_w = state_r;
            end
        endcase
    end

    always_ff @(posedge avm_clk or posedge avm_rst) begin
        if (avm_rst) begin
            n_r <= 0;
            d_r <= 0;
            enc_r <= 0;
            dec_r <= 0;
            avm_address_r <= STATUS_BASE;
            avm_read_r <= 1;
            avm_write_r <= 0;
            state_r <= S_GET_KEY;
            bytes_counter_r <= 63;
            rsa_start_r <= 0;
        end
        else begin
            n_r <= n_w;
            d_r <= d_w;
            enc_r <= enc_w;
            dec_r <= dec_w;
            avm_address_r <= avm_address_w;
            avm_read_r <= avm_read_w;
            avm_write_r <= avm_write_w;
            bytes_counter_r <= bytes_counter_w;
            rsa_start_r <= rsa_start_w;

            if(bytes_counter_w[6] == 1'b1) begin
                case(state_w)
                    S_GET_KEY: bytes_counter_r <= 7'd31;
                    S_GET_DATA: bytes_counter_r <= 7'd31;
                    S_WAIT_CALCULATE: bytes_counter_r <= bytes_counter_w;
                    S_SEND_DATA: bytes_counter_r <= 7'd30;
                    default: bytes_counter_r <= bytes_counter_w;
                endcase
            end
            else bytes_counter_r <= bytes_counter_w;

            state_r <= state_w;
        end
    end

endmodule
