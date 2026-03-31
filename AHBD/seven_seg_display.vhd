library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity seven_seg_display is
    port (
        CLK       : in std_logic;
        SCORE_D0  : in natural range 0 to 9;
        SCORE_D1  : in natural range 0 to 9;
        SCORE_D2  : in natural range 0 to 9;
        SCORE_D3  : in natural range 0 to 9;
        SSD_SEG   : out std_logic_vector(6 downto 0);
        SSD_COM   : out std_logic_vector(3 downto 0)
    );
end seven_seg_display;

architecture Behavioral of seven_seg_display is
    signal refresh_counter : std_logic_vector(15 downto 0) := (others => '0');
begin
    process(CLK)
        variable digit_sel : std_logic_vector(1 downto 0);
        variable v_bcd : natural range 0 to 9;
    begin
        if rising_edge(CLK) then
            refresh_counter <= refresh_counter + 1; 
            digit_sel := refresh_counter(15 downto 14);
            
            case digit_sel is
                when "00" => SSD_COM <= "1110"; v_bcd := SCORE_D0;
                when "01" => SSD_COM <= "1101"; v_bcd := SCORE_D1;
                when "10" => SSD_COM <= "1011"; v_bcd := SCORE_D2;
                when others => SSD_COM <= "0111"; v_bcd := SCORE_D3;
            end case;

            case v_bcd is
                when 0 => SSD_SEG <= "0111111";
                when 1 => SSD_SEG <= "0000110";
                when 2 => SSD_SEG <= "1011011";
                when 3 => SSD_SEG <= "1001111";
                when 4 => SSD_SEG <= "1100110";
                when 5 => SSD_SEG <= "1101101";
                when 6 => SSD_SEG <= "1111101";
                when 7 => SSD_SEG <= "0000111";
                when 8 => SSD_SEG <= "1111111";
                when 9 => SSD_SEG <= "1101111";
                when others => SSD_SEG <= "0000000";
            end case;
        end if;
    end process;
end Behavioral;