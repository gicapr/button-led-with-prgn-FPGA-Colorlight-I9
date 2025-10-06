`timescale 1ns/1ps

module btn_led_prng (
    input  wire clk,
    input  wire btn_raw,
    output wire led_onboard,
    output wire led_ext
);

    wire reset_n = 1'b1;

    wire btn_db;
    debounce u_debounce (
        .clk(clk),
        .reset_n(reset_n),
        .btn_in(btn_raw),
        .btn_out(btn_db)
    );

    wire tick_1hz, sec_phase;
    clk_divider u_clkdiv (
        .clk(clk), .reset_n(reset_n),
        .tick(tick_1hz), .sec_phase(sec_phase)
    );

    reg [15:0] lfsr = 16'hA5A5;
    always @(posedge clk or negedge reset_n)
        if (!reset_n) lfsr <= 16'hA5A5;
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

    function automatic [3:0] lfsr_to_1_10(input [15:0] v);
        logic [3:0] tmp;
        begin
            tmp = v[3:0];
            if (tmp <= 8) lfsr_to_1_10 = tmp + 1;
            else lfsr_to_1_10 = 10;
        end
    endfunction

    typedef enum logic [1:0] {S_COUNT, S_WAIT_BUTTON} state_t;
    state_t state;

    reg [3:0] sec_cnt, target_sec, prev_target;
    reg led_onboard_r, led_ext_r;

    assign led_onboard = led_onboard_r;
    assign led_ext     = led_ext_r;

    reg btn_db_prev, btn_pressed;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            btn_db_prev <= 0; btn_pressed <= 0;
        end else begin
            btn_db_prev <= btn_db;
            btn_pressed <= btn_db && !btn_db_prev;
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_COUNT;
            sec_cnt <= 0;
            target_sec <= 1;
            prev_target <= 0;
            led_onboard_r <= 0;
            led_ext_r <= 0;
        end else begin
            led_onboard_r <= sec_phase;

            case (state)
                S_COUNT: begin
                    if (tick_1hz) begin
                        if ((sec_cnt + 1) == target_sec)
                            led_ext_r <= 1;
                        else
                            led_ext_r <= 0;

                        if (sec_cnt == 9) begin
                            sec_cnt <= 0;
                            state <= S_WAIT_BUTTON;
                            led_ext_r <= 0;
                        end else
                            sec_cnt <= sec_cnt + 1;
                    end
                end

                S_WAIT_BUTTON: begin
                    led_ext_r <= 0;
                    if (btn_pressed) begin
                        logic [3:0] candidate;
                        candidate = lfsr_to_1_10(lfsr);
                        if (candidate == prev_target)
                            candidate = (candidate == 10) ? 1 : candidate + 1;
                        prev_target <= candidate;
                        target_sec <= candidate;
                        sec_cnt <= 0;
                        state <= S_COUNT;
                    end
                end
            endcase
        end
    end
endmodule

module debounce (
    input  wire clk,
    input  wire reset_n,
    input  wire btn_in,
    output wire btn_out
);
    reg [1:0] sync;
    always @(posedge clk or negedge reset_n)
        if (!reset_n) sync <= 0;
        else sync <= {sync[0], btn_in};

    localparam integer MAX_COUNT = 500000;
    localparam integer CNT_BITS  = 19;  
    reg [CNT_BITS-1:0] cnt;
    reg state;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            cnt <= 0; state <= 0;
        end else begin
            if (sync[1] == state) cnt <= 0;
            else if (cnt >= (MAX_COUNT-1)) begin
                state <= sync[1];
                cnt <= 0;
            end else
                cnt <= cnt + 1;
        end
    end
    assign btn_out = state;
endmodule

module clk_divider (
    input  wire clk,
    input  wire reset_n,
    output reg  tick,
    output reg  sec_phase
);
    localparam integer PERIOD = 25_000_000;
    localparam integer WIDTH  = 25;    
    reg [WIDTH-1:0] counter;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            counter <= 0; tick <= 0; sec_phase <= 0;
        end else begin
            if (counter >= PERIOD-1) begin
                counter <= 0; tick <= 1;
            end else begin
                counter <= counter + 1; tick <= 0;
            end
            sec_phase <= (counter < (PERIOD >> 1));
        end
    end
endmodule