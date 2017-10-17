library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity my_hrw is

  port
  (
    clk      : in  std_logic;
    rst_b    : in  std_logic;
    valid_in : in  std_logic;
    data_in  : in  std_logic_vector(511 downto 0);
    data_out : out std_logic_vector(511 downto 0)
  );

end entity;

architecture rtl of my_hrw is
begin
  process(clk)
  begin
    if(rising_edge(clk)) then

      --  TODO: modify your code HERE!

      data_out <= data_in;
    end if;
  end process;
end rtl;

