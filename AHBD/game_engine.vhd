library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MAIN is
    port (
        CLOCK       : in std_logic;
        SW_MODE     : in std_logic;
        SW_DIFF0    : in std_logic;
        SW_DIFF1    : in std_logic;
        P1_LEFT     : in std_logic;
        P1_RIGHT    : in std_logic;
        P1_START    : in std_logic;
        P2_LEFT     : in std_logic;
        P2_RIGHT    : in std_logic;
        HSYNC       : out std_logic;
        VSYNC       : out std_logic;
        RED         : out std_logic;
        GREEN       : out std_logic;
        BLUE        : out std_logic;
        BUZZER      : out std_logic;
        LED         : out std_logic_vector(2 downto 0);
        SSD_SEG     : out std_logic_vector(6 downto 0);
        SSD_COM     : out std_logic_vector(3 downto 0)
    );
end MAIN;

architecture Structural of MAIN is

    -- 1. ประกาศ Component: ตัวกันปุ่มเด้ง
    component debouncer is
        port ( CLK : in std_logic; BTN_IN : in std_logic; BTN_OUT : out std_logic );
    end component;

    -- 2. ประกาศ Component: 7-Segment
    component seven_seg_display is
        port (
            CLK       : in std_logic;
            SCORE_D0  : in natural range 0 to 9;
            SCORE_D1  : in natural range 0 to 9;
            SCORE_D2  : in natural range 0 to 9;
            SCORE_D3  : in natural range 0 to 9;
            SSD_SEG   : out std_logic_vector(6 downto 0);
            SSD_COM   : out std_logic_vector(3 downto 0)
        );
    end component;

    -- 3. ประกาศ Component: เกมเอนจิ้น
    component game_engine is
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
    end component;

    -- ==========================================================
    -- Signals (สายไฟสำหรับเชื่อมต่อระหว่างบล็อก)
    -- ==========================================================
    signal w_btn_p1_l, w_btn_p1_r, w_btn_p1_s : std_logic;
    signal w_btn_p2_l, w_btn_p2_r : std_logic;
    
    signal w_score_0, w_score_1, w_score_2, w_score_3 : natural range 0 to 9;

begin

    -- 1. เชื่อมต่อ Debouncer เข้ากับปุ่มกดบนบอร์ด
    DB_P1_L: debouncer port map (CLK => CLOCK, BTN_IN => P1_LEFT,  BTN_OUT => w_btn_p1_l);
    DB_P1_R: debouncer port map (CLK => CLOCK, BTN_IN => P1_RIGHT, BTN_OUT => w_btn_p1_r);
    DB_P1_S: debouncer port map (CLK => CLOCK, BTN_IN => P1_START, BTN_OUT => w_btn_p1_s);
    DB_P2_L: debouncer port map (CLK => CLOCK, BTN_IN => P2_LEFT,  BTN_OUT => w_btn_p2_l);
    DB_P2_R: debouncer port map (CLK => CLOCK, BTN_IN => P2_RIGHT, BTN_OUT => w_btn_p2_r);

    -- 2. เชื่อมต่อ Game Engine (รับค่าจากปุ่ม และส่งออกจอภาพ/คะแนน)
    GAME_CORE: game_engine port map (
        CLK         => CLOCK,
        SW_MODE     => SW_MODE,
        SW_DIFF0    => SW_DIFF0,
        SW_DIFF1    => SW_DIFF1,
        BTN_P1_L    => w_btn_p1_l,
        BTN_P1_R    => w_btn_p1_r,
        BTN_P1_S    => w_btn_p1_s,
        BTN_P2_L    => w_btn_p2_l,
        BTN_P2_R    => w_btn_p2_r,
        HSYNC       => HSYNC,
        VSYNC       => VSYNC,
        RED         => RED,
        GREEN       => GREEN,
        BLUE        => BLUE,
        BUZZER      => BUZZER,
        LED         => LED,
        SCORE_D0    => w_score_0,
        SCORE_D1    => w_score_1,
        SCORE_D2    => w_score_2,
        SCORE_D3    => w_score_3
    );

    -- 3. เชื่อมต่อ 7-Segment
    Inst_7Seg: seven_seg_display port map (
        CLK      => CLOCK,
        SCORE_D0 => w_score_0,
        SCORE_D1 => w_score_1,
        SCORE_D2 => w_score_2,
        SCORE_D3 => w_score_3,
        SSD_SEG  => SSD_SEG,
        SSD_COM  => SSD_COM
    );

end Structural;