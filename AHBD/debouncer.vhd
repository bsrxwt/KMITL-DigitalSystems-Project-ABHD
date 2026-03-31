library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity debouncer is
    port (
        CLK      : in std_logic;
        BTN_IN   : in std_logic;
        BTN_OUT  : out std_logic
    );
end debouncer;

architecture Behavioral of debouncer is
    signal counter : integer range 0 to 50000 := 0;
begin
    process(CLK)
    begin
        if rising_edge(CLK) then
            if BTN_IN = '0' then 
                counter <= 50000; 
            end if;
            
            if counter > 0 then 
                counter <= counter - 1; 
                BTN_OUT <= '1'; 
            else 
                BTN_OUT <= '0'; 
            end if;
        end if;
    end process;
end Behavioral;