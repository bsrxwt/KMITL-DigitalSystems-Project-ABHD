library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.image_pack.all;

entity game_engine is
    port (
        CLK         : in std_logic;
        SW_MODE     : in std_logic;
        SW_DIFF0    : in std_logic;
        SW_DIFF1    : in std_logic;
        BTN_P1_L    : in std_logic;
        BTN_P1_R    : in std_logic;
        BTN_P1_S    : in std_logic;
        BTN_P2_L    : in std_logic;
        BTN_P2_R    : in std_logic;
        HSYNC       : out std_logic;
        VSYNC       : out std_logic;
        RED         : out std_logic;
        GREEN       : out std_logic;
        BLUE        : out std_logic;
        BUZZER      : out std_logic;
        LED         : out std_logic_vector(2 downto 0);
        SCORE_D0    : out natural range 0 to 9;
        SCORE_D1    : out natural range 0 to 9;
        SCORE_D2    : out natural range 0 to 9;
        SCORE_D3    : out natural range 0 to 9
    );
end game_engine;

architecture Behavioral of game_engine is
    signal sig_heart : natural range 0 to 3 := 0;
    signal freq_counter : std_logic_vector(14 downto 0) := (others => '0');
    
    constant X_WHOLE_LINE : natural := 635;  constant X_SYNC_PULSE : natural := 76;
    constant X_BACK_PORCH : natural := 38;   constant X_FRONT_PORCH : natural := 13;
    constant Y_WHOLE_FRAME : natural := 525; constant Y_SYNC_PULSE : natural := 2;
    constant Y_BACK_PORCH : natural := 33;   constant Y_FRONT_PORCH : natural := 10;
    constant LEFT_BORDER : natural := 115;   constant RIGHT_BORDER : natural := 624;
    constant UP_BORDER : natural := 36;      constant DOWN_BORDER : natural := 516;
    constant GAME_WIDTH : natural := 509;    constant GAME_HEIGHT : natural := 480;

    type t_rectangle is record 
        x, y : integer range -64 to 1023; 
        dx, dy : integer range -15 to 15; 
        w, h : natural range 0 to 1023; 
        e : boolean; 
    end record;
    type t_color is record r, g, b : std_logic; end record;
    type t_colors is record color1, color2 : t_color; end record;
    type t_brick is record state : natural range 0 to 1; end record;

    constant color_black : t_colors := (('0','0','0'), ('0','0','0'));
    constant color_white : t_colors := (('1','1','1'), ('1','1','1'));
    constant color_red   : t_colors := (('1','0','0'), ('1','0','0'));
    constant color_orange: t_colors := (('1','1','0'), ('1','0','0'));
    constant color_teal  : t_colors := (('0','1','1'), ('0','0','1'));
    constant color_green : t_colors := (('0','1','0'), ('0','1','0'));
    
    type t_color_array is array (0 to 11) of t_colors;
    constant color_array : t_color_array := (
        0=>color_red, 1=>color_orange, 2=>(('1','1','0'),('1','1','0')), 3=>(('1','1','0'),('0','1','0')),
        4=>color_green, 5=>(('0','1','1'),('0','1','0')), 6=>(('0','1','1'),('0','1','1')), 7=>color_teal,
        8=>(('0','0','1'),('0','0','1')), 9=>(('1','0','1'),('0','0','1')), 10=>(('1','0','1'),('1','0','1')), 11=>(('1','0','1'),('1','0','0'))
    );

    type t_state is (S_MENU, S_READY, S_PLAYING, S_PAUSE, S_WIN, S_LOSE);

begin
    LED(0) <= '1' when sig_heart >= 1 else '0'; 
    LED(1) <= '1' when sig_heart >= 2 else '0'; 
    LED(2) <= '1' when sig_heart >= 3 else '0';

    process(CLK)
    begin
        if rising_edge(CLK) then freq_counter <= freq_counter + 1; end if;
    end process;

    process(CLK)
        variable x : natural range 0 to X_WHOLE_LINE := 0;
        variable y : natural range 0 to Y_WHOLE_FRAME := 0;
        variable game_counter, buzzer_counter : natural := 0;
        variable game_state : t_state := S_MENU;
        variable pause_delay : natural range 0 to 100 := 0;
        variable active_mode : std_logic := '0';
        variable diff_level : natural range 1 to 3 := 1; 
        variable pause_cursor : natural range 0 to 1 := 0;
        variable timer_tick : natural range 0 to 200 := 0;
        variable t_m1, t_m0, t_s1, t_s0 : natural range 0 to 9 := 0; 
        variable score : natural range 0 to 9999 := 0;
        variable s_d0, s_d1, s_d2, s_d3 : natural range 0 to 9 := 0;
        variable heart, max_heart : natural range 0 to 3 := 0;
        variable base_speed : integer range 1 to 4 := 1;

        variable p1 : t_rectangle := (GAME_WIDTH/4, GAME_HEIGHT*7/8, 0, 0, 48, 8, false);
        variable p2 : t_rectangle := (GAME_WIDTH*3/4, GAME_HEIGHT*7/8, 0, 0, 48, 8, false);
        variable ball : t_rectangle := (GAME_WIDTH/2, GAME_HEIGHT/2, 1, -1, 8, 8, false);
        
        constant BRICK_COUNT_X : natural := 16; constant BRICK_COUNT_Y : natural := 8;
        constant TOTAL_BRICKS : natural := 128; 
        
        type t_brick_array is array (0 to 127) of t_brick;
        variable b_arr : t_brick_array := (others => (state => 1));
        variable brk : t_rectangle := (0, 0, 0, 0, 30, 14, false);
        variable b_color : t_colors;

        type t_rect_arr is array (0 to 3) of t_rectangle;
        variable particles : t_rect_arr := (others => (0,0,0,0,8,8,false));
        variable p_time : natural range 0 to 100 := 0;
        variable v_bx, v_by : natural range 0 to 31 := 0;
        variable v_bidx : natural range 0 to 127 := 0;
        variable img_x, img_y, rom_idx : integer;

        impure function clamp(v, min_v, max_v: integer) return integer is begin if v <= min_v then return min_v; elsif v >= max_v then return max_v; else return v; end if; end function;
        impure function intersect(b1, b2: t_rectangle) return boolean is begin if b1.x > b2.x+b2.w or b2.x > b1.x+b1.w or b1.y > b2.y+b2.h or b2.y > b1.y+b1.h then return false; end if; return true; end function;
        impure function bounce(box1, box2: t_rectangle) return t_rectangle is variable b : t_rectangle := box1; begin
            if intersect(box1, box2) then b.e := true; if b.dy > 0 then b.dy := 0 - b.dy; b.y := b.y + b.dy; end if; end if; return b;
        end function;

        procedure set_c(c: t_color) is begin RED <= c.r; GREEN <= c.g; BLUE <= c.b; end procedure;
        procedure d_rect(r: t_rectangle; c: t_colors; trans: boolean) is variable xx, yy: natural; begin
            xx := r.x + LEFT_BORDER; yy := r.y + UP_BORDER;
            if x >= xx and x < xx+r.w and y >= yy and y < yy+r.h then
                if y mod 2 = 0 then if x mod 2 = 0 then set_c(c.color1); else set_c(c.color2); end if;
                elsif not trans then if x mod 2 = 1 then set_c(c.color1); else set_c(c.color2); end if; end if;
            end if;
        end procedure;

        procedure d_score(s, dx, dy: natural) is begin
            d_rect((dx, dy, 0,0, 12,16, false), color_white, false);
            if s=0 then d_rect((dx+4, dy+2, 0,0, 4,12, false), color_black, false);
            elsif s=1 then d_rect((dx+8, dy, 0,0, 4,14, false), color_black, false); d_rect((dx, dy+2, 0,0, 4,12, false), color_black, false);
            elsif s=2 then d_rect((dx, dy+2, 0,0, 8,5, false), color_black, false); d_rect((dx+4, dy+9, 0,0, 8,5, false), color_black, false);
            elsif s=3 then d_rect((dx, dy+2, 0,0, 8,5, false), color_black, false); d_rect((dx, dy+9, 0,0, 8,5, false), color_black, false);
            elsif s=4 then d_rect((dx+4, dy, 0,0, 4,7, false), color_black, false); d_rect((dx, dy+9, 0,0, 8,7, false), color_black, false);
            elsif s=5 then d_rect((dx+4, dy+2, 0,0, 8,5, false), color_black, false); d_rect((dx, dy+9, 0,0, 8,5, false), color_black, false);
            elsif s=6 then d_rect((dx+4, dy+2, 0,0, 8,5, false), color_black, false); d_rect((dx+4, dy+9, 0,0, 4,5, false), color_black, false);
            elsif s=7 then d_rect((dx, dy+2, 0,0, 8,14, false), color_black, false);
            elsif s=8 then d_rect((dx+4, dy+2, 0,0, 4,5, false), color_black, false); d_rect((dx+4, dy+9, 0,0, 4,5, false), color_black, false);
            elsif s=9 then d_rect((dx+4, dy+2, 0,0, 4,5, false), color_black, false); d_rect((dx, dy+9, 0,0, 8,5, false), color_black, false);
            end if;
        end procedure;

    begin
        if rising_edge(CLK) then
            RED <= '0'; GREEN <= '0'; BLUE <= '0'; 
            
            game_counter := game_counter + 1;
            if game_counter = 150000 then 
                game_counter := 0;
                if pause_delay > 0 then pause_delay := pause_delay - 1; end if;
                
                case game_state is
                    when S_MENU =>
                        active_mode := SW_MODE; 
                        if active_mode = '0' then max_heart := 1; else max_heart := 3; end if;
                        heart := max_heart;
                        if pause_delay = 0 then
                            if BTN_P1_S = '1' then
                                if diff_level = 3 then diff_level := 1; else diff_level := diff_level + 1; end if;
                                pause_delay := 50; buzzer_counter := 50000;
                            end if;
                            if BTN_P1_R = '1' then game_state := S_READY; pause_delay := 50; buzzer_counter := 100000; end if;
                        end if;

                    when S_READY =>
                        active_mode := SW_MODE; 
                        if active_mode = '0' then max_heart := 1; else max_heart := 3; end if;
                        heart := max_heart;
                        if pause_delay = 0 then
                            if BTN_P1_S = '1' then game_state := S_MENU; pause_delay := 50; buzzer_counter := 50000; end if;
                            if BTN_P1_R = '1' then
                                base_speed := diff_level; score := 0; p_time := 0; s_d0 := 0; s_d1 := 0; s_d2 := 0; s_d3 := 0;
                                t_m1 := 0; t_m0 := 0; t_s1 := 0; t_s0 := 0; timer_tick := 0;
                                ball.x := GAME_WIDTH/2; ball.y := GAME_HEIGHT/2; ball.dx := base_speed; ball.dy := -base_speed;
                                b_arr := (others => (state => 1)); game_state := S_PLAYING; buzzer_counter := 500000; pause_delay := 50; 
                            end if;
                        end if;

                    when S_PLAYING =>
                        if BTN_P1_S = '1' and pause_delay = 0 then game_state := S_PAUSE; pause_cursor := 0; pause_delay := 50; buzzer_counter := 50000;
                        else
                            timer_tick := timer_tick + 1;
                            if timer_tick = 133 then 
                                timer_tick := 0;
                                if t_s0 = 9 then t_s0 := 0;
                                    if t_s1 = 5 then t_s1 := 0;
                                        if t_m0 = 9 then t_m0 := 0; if t_m1 < 9 then t_m1 := t_m1 + 1; end if;
                                        else t_m0 := t_m0 + 1; end if;
                                    else t_s1 := t_s1 + 1; end if;
                                else t_s0 := t_s0 + 1; end if;
                            end if;
                        
                            if BTN_P1_L = '1' then p1.dx := -3; elsif BTN_P1_R = '1' then p1.dx := 3; else p1.dx := 0; end if;
                            if BTN_P2_L = '1' then p2.dx := -3; elsif BTN_P2_R = '1' then p2.dx := 3; else p2.dx := 0; end if;
                            
                            if active_mode = '0' then p1.x := clamp(p1.x + p1.dx, 0, GAME_WIDTH - p1.w); else p1.x := clamp(p1.x + p1.dx, 0, (GAME_WIDTH/2) - p1.w); end if;
                            p2.x := clamp(p2.x + p2.dx, (GAME_WIDTH/2), GAME_WIDTH - p2.w);
                            
                            ball.x := ball.x + ball.dx; ball.y := ball.y + ball.dy;
                            if p_time > 0 then p_time := p_time - 1; for i in 0 to 3 loop particles(i).x := particles(i).x + particles(i).dx; particles(i).y := particles(i).y + particles(i).dy; end loop; end if;

                            if ball.x <= 1 or ball.x >= GAME_WIDTH - ball.w then ball.dx := 0 - ball.dx; buzzer_counter := 100000; end if;
                            if ball.y <= 1 then ball.dy := 0 - ball.dy; buzzer_counter := 100000; end if;
                            
                            ball.e := false; ball := bounce(ball, p1); 
                            if not ball.e and active_mode = '1' then ball := bounce(ball, p2); end if;
                            if ball.e then buzzer_counter := 100000; end if;

                            if ball.y >= 32 and ball.y < 160 then
                                v_bx := (ball.x + 4) / 32; v_by := (ball.y + 4 - 32) / 16;
                                if v_bx >= 0 and v_bx <= 15 and v_by >= 0 and v_by <= 7 then
                                    v_bidx := (v_by * 16) + v_bx;
                                    if b_arr(v_bidx).state = 1 then
                                        b_arr(v_bidx).state := 0; ball.dy := 0 - ball.dy; buzzer_counter := 500000; score := score + 1; 
                                        if s_d0 = 9 then s_d0 := 0; if s_d1 = 9 then s_d1 := 0; if s_d2 = 9 then s_d2 := 0; s_d3 := s_d3 + 1; else s_d2 := s_d2 + 1; end if; else s_d1 := s_d1 + 1; end if; else s_d0 := s_d0 + 1; end if;
                                        p_time := 40; b_color := color_array(v_by mod 12);
                                        for i in 0 to 3 loop particles(i).x := ball.x; particles(i).y := ball.y; end loop;
                                        particles(0).dx:=2; particles(0).dy:=2; particles(1).dx:=-2; particles(1).dy:=2;
                                        particles(2).dx:=2; particles(2).dy:=-2; particles(3).dx:=-2; particles(3).dy:=-2;
                                    end if;
                                end if;
                            end if;
                            if ball.y >= GAME_HEIGHT - ball.h then heart := heart - 1; buzzer_counter := 2000000; if heart = 0 then game_state := S_LOSE; else ball.x := GAME_WIDTH/2; ball.y := GAME_HEIGHT/2; ball.dy := -base_speed; end if; end if;
                            if score >= TOTAL_BRICKS then game_state := S_WIN; end if;
                        end if;

                    when S_PAUSE =>
                        if SW_MODE = '0' and heart > 1 then heart := 1; end if;
                        if pause_delay = 0 then if BTN_P1_S = '1' then pause_cursor := 1 - pause_cursor; pause_delay := 50; buzzer_counter := 50000; elsif BTN_P1_R = '1' then if pause_cursor = 0 then game_state := S_PLAYING; else game_state := S_MENU; end if; pause_delay := 50; buzzer_counter := 100000; end if; end if;
                    when S_WIN | S_LOSE =>
                        if BTN_P1_R = '1' and pause_delay = 0 then game_state := S_MENU; buzzer_counter := 500000; pause_delay := 50; end if;
                end case;
            end if; 
            
            SCORE_D0 <= s_d0; SCORE_D1 <= s_d1; SCORE_D2 <= s_d2; SCORE_D3 <= s_d3; 
            sig_heart <= heart;
            
            if buzzer_counter > 0 then buzzer_counter := buzzer_counter - 1; BUZZER <= freq_counter(14); else BUZZER <= '0'; end if;

            if x >= LEFT_BORDER and x < RIGHT_BORDER and y >= UP_BORDER and y < DOWN_BORDER then
                if game_state = S_MENU or game_state = S_READY then 
                    set_c(color_teal.color1); 
                    d_rect((2, 2, 0,0, GAME_WIDTH-4, GAME_HEIGHT-4, false), color_teal, false);
                    d_rect((6, 6, 0,0, GAME_WIDTH-12, GAME_HEIGHT-12, false), color_black, false);
                    
                    d_rect((184, 104, 0,0, 10,40, false), color_teal, false); d_rect((194, 104, 0,0, 20,10, false), color_teal, false); d_rect((214, 104, 0,0, 10,20, false), color_teal, false); d_rect((194, 124, 0,0, 20,10, false), color_teal, false); d_rect((234, 104, 0,0, 10,40, false), color_teal, false); d_rect((244, 134, 0,0, 20,10, false), color_teal, false); d_rect((274, 114, 0,0, 10,30, false), color_teal, false); d_rect((284, 104, 0,0, 20,10, false), color_teal, false); d_rect((304, 114, 0,0, 10,30, false), color_teal, false); d_rect((284, 124, 0,0, 20,10, false), color_teal, false); d_rect((324, 104, 0,0, 10,20, false), color_teal, false); d_rect((344, 104, 0,0, 10,20, false), color_teal, false); d_rect((334, 124, 0,0, 10,20, false), color_teal, false);

                    d_rect((180, 100, 0,0, 10,40, false), color_white, false); d_rect((190, 100, 0,0, 20,10, false), color_white, false); d_rect((210, 100, 0,0, 10,20, false), color_white, false); d_rect((190, 120, 0,0, 20,10, false), color_white, false); d_rect((230, 100, 0,0, 10,40, false), color_white, false); d_rect((240, 130, 0,0, 20,10, false), color_white, false); d_rect((270, 110, 0,0, 10,30, false), color_white, false); d_rect((280, 100, 0,0, 20,10, false), color_white, false); d_rect((300, 110, 0,0, 10,30, false), color_white, false); d_rect((280, 120, 0,0, 20,10, false), color_white, false); d_rect((320, 100, 0,0, 10,20, false), color_white, false); d_rect((340, 100, 0,0, 10,20, false), color_white, false); d_rect((330, 120, 0,0, 10,20, false), color_white, false);

                    d_rect(((GAME_WIDTH/2) - 50, (GAME_HEIGHT/2) - 20, 0,0, 100, 40, false), color_white, false);
                    d_rect(((GAME_WIDTH/2) - 46, (GAME_HEIGHT/2) - 16, 0,0,  92, 32, false), color_black, false);
                    
                    if game_state = S_MENU then
                        if (game_counter / 20000) mod 2 = 0 then
                            if diff_level = 1 then d_rect(((GAME_WIDTH/2) - 44, (GAME_HEIGHT/2) - 14, 0,0, 28, 28, false), color_green, false); d_rect(((GAME_WIDTH/2) - 40, (GAME_HEIGHT/2) - 10, 0,0, 20, 20, false), color_black, false);
                            elsif diff_level = 2 then d_rect(((GAME_WIDTH/2) - 14, (GAME_HEIGHT/2) - 14, 0,0, 28, 28, false), color_orange, false); d_rect(((GAME_WIDTH/2) - 10, (GAME_HEIGHT/2) - 10, 0,0, 20, 20, false), color_black, false);
                            elsif diff_level = 3 then d_rect(((GAME_WIDTH/2) + 16, (GAME_HEIGHT/2) - 14, 0,0, 28, 28, false), color_red, false); d_rect(((GAME_WIDTH/2) + 20, (GAME_HEIGHT/2) - 10, 0,0, 20, 20, false), color_black, false);
                            end if;
                        end if;
                    end if;

                    if diff_level >= 1 then d_rect(((GAME_WIDTH/2) - 40, (GAME_HEIGHT/2) - 10, 0,0, 20, 20, false), color_green, false); d_rect(((GAME_WIDTH/2) - 38, (GAME_HEIGHT/2) -  8, 0,0,  4,  4, false), color_white, false); end if;
                    if diff_level >= 2 then d_rect(((GAME_WIDTH/2) - 10, (GAME_HEIGHT/2) - 10, 0,0, 20, 20, false), color_orange, false); d_rect(((GAME_WIDTH/2) -  8, (GAME_HEIGHT/2) -  8, 0,0,  4,  4, false), color_white, false); end if;
                    if diff_level >= 3 then d_rect(((GAME_WIDTH/2) + 20, (GAME_HEIGHT/2) - 10, 0,0, 20, 20, false), color_red, false); d_rect(((GAME_WIDTH/2) + 22, (GAME_HEIGHT/2) -  8, 0,0,  4,  4, false), color_white, false); end if;

                    if game_state = S_READY then
                        d_rect(((GAME_WIDTH/2) - 40, (GAME_HEIGHT/2) + 30, 0,0, 80, 10, false), color_green, false);
                        d_rect(((GAME_WIDTH/2) - 38, (GAME_HEIGHT/2) + 32, 0,0, 76,  6, false), color_black, false);
                        if (game_counter / 15000) mod 2 = 0 then d_rect(((GAME_WIDTH/2) - 36, (GAME_HEIGHT/2) + 34, 0,0, 72, 2, false), color_green, false); end if;
                    end if;

                elsif game_state = S_WIN or game_state = S_LOSE then 
                    set_c(color_black.color1); 
                    img_x := (x - LEFT_BORDER - 62) / 3; img_y := (y - UP_BORDER - 48) / 3;
                    if img_x >= 0 and img_x < 128 and img_y >= 0 and img_y < 128 then
                        rom_idx := (img_y * 128) + img_x;
                        if BOSS_IMG(rom_idx) = '1' then set_c(color_white.color1); else set_c(color_black.color1); end if;
                    end if;
                    
                    if game_state = S_WIN then
                        d_rect((194, 180, 0,0, 10,50, false), color_green, false); d_rect((204, 210, 0,0, 10,20, false), color_green, false); d_rect((214, 200, 0,0, 10,30, false), color_green, false); d_rect((224, 210, 0,0, 10,20, false), color_green, false); d_rect((234, 180, 0,0, 10,50, false), color_green, false); d_rect((254, 180, 0,0, 10,50, false), color_green, false); d_rect((274, 180, 0,0, 10,50, false), color_green, false); d_rect((284, 190, 0,0, 10,15, false), color_green, false); d_rect((294, 205, 0,0, 10,15, false), color_green, false); d_rect((304, 180, 0,0, 10,50, false), color_green, false);
                    else
                        d_rect((159, 180, 0,0, 10,50, false), color_red, false); d_rect((169, 220, 0,0, 30,10, false), color_red, false); d_rect((209, 180, 0,0, 10,50, false), color_red, false); d_rect((219, 180, 0,0, 20,10, false), color_red, false); d_rect((219, 220, 0,0, 20,10, false), color_red, false); d_rect((239, 180, 0,0, 10,50, false), color_red, false); d_rect((259, 180, 0,0, 40,10, false), color_red, false); d_rect((259, 190, 0,0, 10,10, false), color_red, false); d_rect((259, 200, 0,0, 40,10, false), color_red, false); d_rect((289, 210, 0,0, 10,10, false), color_red, false); d_rect((259, 220, 0,0, 40,10, false), color_red, false); d_rect((309, 180, 0,0, 10,50, false), color_red, false); d_rect((319, 180, 0,0, 30,10, false), color_red, false); d_rect((319, 200, 0,0, 20,10, false), color_red, false); d_rect((319, 220, 0,0, 30,10, false), color_red, false);
                    end if;

                    d_rect((210, 265, 0,0, 10,10, false), color_orange, false); d_rect((212, 267, 0,0, 6,6, false), color_white, false);
                    d_score(s_d3, 230, 262); d_score(s_d2, 246, 262); d_score(s_d1, 262, 262); d_score(s_d0, 278, 262);
                    d_rect((210, 290, 0,0, 10,10, false), color_teal, false); d_rect((214, 292, 0,0, 2,4, false), color_black, false); d_rect((214, 294, 0,0, 4,2, false), color_black, false);
                    d_score(t_m1, 230, 287); d_score(t_m0, 246, 287); 
                    d_rect((260, 291, 0,0, 2,2, false), color_white, false); d_rect((260, 297, 0,0, 2,2, false), color_white, false);
                    d_score(t_s1, 264, 287); d_score(t_s0, 280, 287); 

                elsif game_state = S_PLAYING or game_state = S_PAUSE then
                    if active_mode = '1' and x = LEFT_BORDER + (GAME_WIDTH/2) then set_c(color_white.color1); end if;
                    if x >= LEFT_BORDER and x < LEFT_BORDER + 512 and y >= UP_BORDER + 32 and y < UP_BORDER + 32 + 128 then
                        v_bx := (x - LEFT_BORDER) / 32; v_by := (y - UP_BORDER - 32) / 16; v_bidx := (v_by * 16) + v_bx;
                        if b_arr(v_bidx).state = 1 then if ((x - LEFT_BORDER) mod 32) < 30 and ((y - UP_BORDER - 32) mod 16) < 14 then set_c(color_array(v_by mod 12).color1); end if; end if;
                    end if;
                    if p_time > 0 then for i in 0 to 3 loop d_rect(particles(i), b_color, true); end loop; end if;
                    
                    d_rect(p1, color_orange, false); if active_mode = '1' then d_rect(p2, color_teal, false); end if;
                    d_rect((ball.x+2, ball.y,   0,0, 4,1, false), color_white, false); d_rect((ball.x+1, ball.y+1, 0,0, 6,1, false), color_white, false); d_rect((ball.x,   ball.y+2, 0,0, 8,4, false), color_white, false); d_rect((ball.x+1, ball.y+6, 0,0, 6,1, false), color_white, false); d_rect((ball.x+2, ball.y+7, 0,0, 4,1, false), color_white, false);
                    
                    d_rect((32, 8, 0,0, 12,16, false), color_white, false); d_rect((36, 10, 0,0, 4,12, false), color_black, false); 
                    d_rect((48, 8, 0,0, 12,16, false), color_white, false); d_rect((52, 10, 0,0, 4,12, false), color_black, false); 
                    d_score(s_d2, 64, 8); d_score(s_d1, 80, 8); d_score(s_d0, 96, 8);
                    
                    for i in 0 to 2 loop
                        if heart > i then
                            d_rect(((GAME_WIDTH*3/4)+(24*i) + 4,  8, 0,0, 4,2, false), color_red, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 12, 8, 0,0, 4,2, false), color_red, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 2,  10, 0,0, 10,2, false), color_red, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 12, 10, 0,0, 2,2, false), color_white, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 14, 10, 0,0, 4,2, false), color_red, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 2,  12, 0,0, 16,2, false), color_red, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 4,  14, 0,0, 12,2, false), color_red, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 6,  16, 0,0, 8,2, false), color_red, false); d_rect(((GAME_WIDTH*3/4)+(24*i) + 8,  18, 0,0, 4,2, false), color_red, false);
                        end if;
                    end loop;
                    
                    if game_state = S_PAUSE then
                        d_rect(((GAME_WIDTH/2) - 60, (GAME_HEIGHT/2) - 70, 0,0, 140, 160, false), color_black, false);
                        d_rect(((GAME_WIDTH/2) - 70, (GAME_HEIGHT/2) - 80, 0,0, 140, 160, false), color_teal, false);
                        d_rect(((GAME_WIDTH/2) - 66, (GAME_HEIGHT/2) - 76, 0,0, 132, 152, false), color_black, false);
                        d_rect(((GAME_WIDTH/2) - 15, (GAME_HEIGHT/2) - 60, 0,0, 10, 20, false), color_orange, false);
                        d_rect(((GAME_WIDTH/2) + 5,  (GAME_HEIGHT/2) - 60, 0,0, 10, 20, false), color_orange, false);

                        if (game_counter / 20000) mod 2 = 0 then
                            if pause_cursor = 0 then d_rect(((GAME_WIDTH/2) - 44, (GAME_HEIGHT/2) - 24, 0,0, 88, 38, false), color_white, false);
                            else d_rect(((GAME_WIDTH/2) - 44, (GAME_HEIGHT/2) + 16, 0,0, 88, 38, false), color_white, false); end if;
                        end if;

                        d_rect(((GAME_WIDTH/2) - 40, (GAME_HEIGHT/2) - 20, 0,0, 80, 30, false), color_green, false); d_rect(((GAME_WIDTH/2) - 38, (GAME_HEIGHT/2) - 18, 0,0, 4, 4, false), color_white, false); d_rect(((GAME_WIDTH/2) - 4,  (GAME_HEIGHT/2) - 13, 0,0, 4, 16, false), color_white, false); d_rect(((GAME_WIDTH/2) + 0,  (GAME_HEIGHT/2) -  9, 0,0, 4,  8, false), color_white, false); d_rect(((GAME_WIDTH/2) + 4,  (GAME_HEIGHT/2) -  7, 0,0, 4,  4, false), color_white, false);
                        d_rect(((GAME_WIDTH/2) - 40, (GAME_HEIGHT/2) + 20, 0,0, 80, 30, false), color_red, false); d_rect(((GAME_WIDTH/2) - 38, (GAME_HEIGHT/2) + 22, 0,0, 4, 4, false), color_white, false); d_rect(((GAME_WIDTH/2) - 10, (GAME_HEIGHT/2) + 25, 0,0,  4, 20, false), color_white, false); d_rect(((GAME_WIDTH/2) -  6, (GAME_HEIGHT/2) + 41, 0,0, 16,  4, false), color_white, false); d_rect(((GAME_WIDTH/2) +  6, (GAME_HEIGHT/2) + 34, 0,0,  4,  7, false), color_white, false); d_rect(((GAME_WIDTH/2) -  6, (GAME_HEIGHT/2) + 25, 0,0,  9,  4, false), color_white, false); d_rect(((GAME_WIDTH/2) +  3, (GAME_HEIGHT/2) + 25, 0,0, 10,  3, false), color_white, false); d_rect(((GAME_WIDTH/2) +  5, (GAME_HEIGHT/2) + 28, 0,0,  6,  3, false), color_white, false); d_rect(((GAME_WIDTH/2) +  7, (GAME_HEIGHT/2) + 31, 0,0,  2,  3, false), color_white, false); 
                    end if;
                end if;
            end if;

            if x > 0 and x <= X_SYNC_PULSE then HSYNC <= '0'; else HSYNC <= '1'; end if;
            if y > 0 and y <= Y_SYNC_PULSE then VSYNC <= '0'; else VSYNC <= '1'; end if;
            
            x := x + 1; if x = X_WHOLE_LINE then y := y + 1; x := 0; end if;
            if y = Y_WHOLE_FRAME then y := 0; end if;
        end if;
    end process;
end Behavioral;