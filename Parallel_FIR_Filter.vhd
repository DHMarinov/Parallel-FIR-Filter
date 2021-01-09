--| |-----------------------------------------------------------| |
--| |-----------------------------------------------------------| |
--| |       _______           __      __      __          __    | |
--| |     /|   __  \        /|  |   /|  |   /|  \        /  |   | |
--| |    / |  |  \  \      / |  |  / |  |  / |   \      /   |   | |
--| |   |  |  |\  \  \    |  |  | |  |  | |  |    \    /    |   | |
--| |   |  |  | \  \  \   |  |  | |  |  | |  |     \  /     |   | |
--| |   |  |  |  \  \  \  |  |  |_|__|  | |  |      \/      |   | |
--| |   |  |  |   \  \  \ |  |          | |  |  |\      /|  |   | |
--| |   |  |  |   /  /  / |  |   ____   | |  |  | \    / |  |   | |
--| |   |  |  |  /  /  /  |  |  |__/ |  | |  |  |\ \  /| |  |   | |
--| |   |  |  | /  /  /   |  |  | |  |  | |  |  | \ \//| |  |   | |
--| |   |  |  |/  /  /    |  |  | |  |  | |  |  |  \|/ | |  |   | |
--| |   |  |  |__/  /     |  |  | |  |  | |  |  |      | |  |   | |
--| |   |  |_______/      |  |__| |  |__| |  |__|      | |__|   | |
--| |   |_/_______/	      |_/__/  |_/__/  |_/__/       |_/__/   | |
--| |                                                           | |
--| |-----------------------------------------------------------| |
--| |=============-Developed by Dimitar H.Marinov-==============| |
--|_|-----------------------------------------------------------|_|

--IP: Parallel FIR Filter
--Version: V1 - Standalone 
--Fuctionality: Generic FIR filter
--IO Description
--  clk     : system clock = sampling clock
--  reset   : resets the M registes (buffers) and the P registers (delay line) of the DSP48 blocks 
--  enable  : acts as bypass switch - bypass(0), active(1) 
--  data_i  : data input (signed)
--  data_o  : data output (signed)
--
--Generics Description
--  FILTER_TAPS  : Specifies the amount of filter taps (multiplications)
--  INPUT_WIDTH  : Specifies the input width (8-25 bits)
--  COEFF_WIDTH  : Specifies the coefficient width (8-18 bits)
--  OUTPUT_WIDTH : Specifies the output width (8-43 bits)
--
--Finished on: 30.06.2019
--Notes: the DSP attribute is required to make use of the DSP slices efficiently
--------------------------------------------------------------------
--================= https://github.com/DHMarinov =================--
--------------------------------------------------------------------



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Parallel_FIR_Filter is
    Generic (
        FILTER_TAPS  : integer := 60;
        INPUT_WIDTH  : integer range 8 to 25 := 24; 
        COEFF_WIDTH  : integer range 8 to 18 := 16;
        OUTPUT_WIDTH : integer range 8 to 43 := 24    -- This should be < (Input+Coeff width-1) 
    );
    Port ( 
           clk    : in STD_LOGIC;
           reset  : in STD_LOGIC;
           enable : in STD_LOGIC;
           data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
           data_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0)
           );
end Parallel_FIR_Filter;

architecture Behavioral of Parallel_FIR_Filter is

attribute use_dsp : string;
attribute use_dsp of Behavioral : architecture is "yes";

constant MAC_WIDTH : integer := COEFF_WIDTH+INPUT_WIDTH;

type input_registers is array(0 to FILTER_TAPS-1) of signed(INPUT_WIDTH-1 downto 0);
signal areg_s  : input_registers := (others=>(others=>'0'));

type coeff_registers is array(0 to FILTER_TAPS-1) of signed(COEFF_WIDTH-1 downto 0);
signal breg_s : coeff_registers := (others=>(others=>'0'));

type mult_registers is array(0 to FILTER_TAPS-1) of signed(INPUT_WIDTH+COEFF_WIDTH-1 downto 0);
signal mreg_s : mult_registers := (others=>(others=>'0'));

type dsp_registers is array(0 to FILTER_TAPS-1) of signed(MAC_WIDTH-1 downto 0);
signal preg_s : dsp_registers := (others=>(others=>'0'));

signal dout_s : std_logic_vector(MAC_WIDTH-1 downto 0);
signal sign_s : signed(MAC_WIDTH-INPUT_WIDTH-COEFF_WIDTH+1 downto 0) := (others=>'0');

--type coefficients is array (0 to FILTER_TAPS-1) of signed(COEFF_WIDTH-1 downto 0);
--signal coeff_s: coefficients :=( 
---- Blackman 500Hz LPF
--x"0005", x"0001", x"0005", x"000C", 
--x"0016", x"0025", x"0037", x"004E", 
--x"0069");

-- Chebyshev 1kH LPF, causes overflow at low freq. 
type coefficients is array (0 to 59) of signed( 15 downto 0);
signal coeff_s: coefficients :=( 
--x"FFFF", x"FFFF", x"FFFF", x"FFFF", x"FFFF", x"FFFE", 
--x"FFFE", x"FFFF", x"0001", x"0007", x"0011", x"0022", 
--x"003B", x"005E", x"008E", x"00CD", x"011C", x"017C", 
--x"01ED", x"026F", x"02FF", x"0399", x"0439", x"04D9", 
--x"0573", x"0601", x"067B", x"06DD", x"0721", x"0744", 
--x"0744", x"0721", x"06DD", x"067B", x"0601", x"0573", 
--x"04D9", x"0439", x"0399", x"02FF", x"026F", x"01ED", 
--x"017C", x"011C", x"00CD", x"008E", x"005E", x"003B", 
--x"0022", x"0011", x"0007", x"0001", x"FFFF", x"FFFE", 
--x"FFFE", x"FFFF", x"FFFF", x"FFFF", x"FFFF", x"FFFF");

-- 500Hz Blackman LPF
x"0000", x"0001", x"0005", x"000C", 
x"0016", x"0025", x"0037", x"004E", 
x"0069", x"008B", x"00B2", x"00E0", 
x"0114", x"014E", x"018E", x"01D3", 
x"021D", x"026A", x"02BA", x"030B", 
x"035B", x"03AA", x"03F5", x"043B", 
x"047B", x"04B2", x"04E0", x"0504", 
x"051C", x"0528", x"0528", x"051C", 
x"0504", x"04E0", x"04B2", x"047B", 
x"043B", x"03F5", x"03AA", x"035B", 
x"030B", x"02BA", x"026A", x"021D", 
x"01D3", x"018E", x"014E", x"0114", 
x"00E0", x"00B2", x"008B", x"0069", 
x"004E", x"0037", x"0025", x"0016", 
x"000C", x"0005", x"0001", x"0000");


begin  

-- Coefficient formatting
Coeff_Array: for i in 0 to FILTER_TAPS-1 generate
    Coeff: for n in 0 to COEFF_WIDTH-1 generate
        Coeff_Sign: if n > COEFF_WIDTH-2 generate
            breg_s(i)(n) <= coeff_s(i)(COEFF_WIDTH-1);
        end generate;
        Coeff_Value: if n < COEFF_WIDTH-1 generate
            breg_s(i)(n) <= coeff_s(i)(n);
        end generate;
    end generate;
end generate;

data_o <= std_logic_vector(preg_s(0)(MAC_WIDTH-2 downto MAC_WIDTH-OUTPUT_WIDTH-1));         
      

process(clk)
begin

if rising_edge(clk) then

    if (reset = '1') then
        for i in 0 to FILTER_TAPS-1 loop
            areg_s(i) <=(others=> '0');
            mreg_s(i) <=(others=> '0');
            preg_s(i) <=(others=> '0');
        end loop;

    elsif (reset = '0') then        
        for i in 0 to FILTER_TAPS-1 loop
            for n in 0 to INPUT_WIDTH-1 loop
                if n > INPUT_WIDTH-2 then
                    areg_s(i)(n) <= data_i(INPUT_WIDTH-1); 
                else
                    areg_s(i)(n) <= data_i(n);              
                end if;
            end loop;
      
            if (i < FILTER_TAPS-1) then
                mreg_s(i) <= areg_s(i)*breg_s(i);         
                preg_s(i) <= mreg_s(i) + preg_s(i+1);
                        
            elsif (i = FILTER_TAPS-1) then
                mreg_s(i) <= areg_s(i)*breg_s(i); 
                preg_s(i)<= mreg_s(i);
            end if;
        end loop; 
    end if;
    
end if;
end process;

end Behavioral;