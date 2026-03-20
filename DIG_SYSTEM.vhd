library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity DIG_SYSTEM is
    Port ( 
        Clk         : in  std_logic;
        Reset       : in  std_logic;
        Input_Raw   : in  std_logic_vector(3 downto 0);
        Signal_Out  : out std_logic;
        Lock_Status : out std_logic;
        Velocity    : out std_logic_vector(7 downto 0)
    );
end DIG_SYSTEM;

architecture Refined_Integrated of DIG_SYSTEM is
    constant ACC_THRESHOLD  : signed(15 downto 0) := to_signed(1024, 16);
    constant ACC_STEP       : signed(15 downto 0) := to_signed(16, 16);
    constant LOCK_LIMIT     : integer := 64;
    constant UNLOCK_LIMIT   : integer := 256;
    constant INITIAL_DELAY  : unsigned(4 downto 0) := "10000";

    signal sync_reg_1, sync_reg_2 : std_logic_vector(3 downto 0);
    signal delayed_bus, error_bus : std_logic_vector(3 downto 0);
    signal combined_error         : std_logic;
    signal phase_acc              : signed(15 downto 0) := (others => '0');
    signal phase_vel              : signed(7 downto 0)  := (others => '0');
    signal base_delay             : unsigned(4 downto 0) := INITIAL_DELAY;
    signal sigma_delta            : unsigned(7 downto 0) := X"80";
    signal dither_val             : unsigned(4 downto 0); 
    signal rdy                    : std_logic;
    signal locked_int             : std_logic := '0';

begin

    IDELAYCTRL_inst : IDELAYCTRL
    port map (RDY => rdy, REFCLK => Clk, RST => Reset);

    dither_val <= "00001" when sigma_delta > 128 else "00000";

    GEN_CORES: for i in 0 to 3 generate
        IDELAY_inst : IDELAYE2
        generic map (
            DELAY_SRC => "IDATAIN",
            IDELAY_TYPE => "VAR_LOAD",
            PIPE_SEL => "FALSE"
        )
        port map (
            IDATAIN     => sync_reg_2(i),
            DATAOUT     => delayed_bus(i),
            CLK         => Clk,
            CNTVALUEIN  => std_logic_vector(base_delay + dither_val),
            LD          => '1', 
            CE          => '0', 
            INC         => '0', 
            REGRST      => Reset, 
            LDPIPEEN    => '0'
        );
        error_bus(i) <= delayed_bus(i) XOR Clk;
    end generate;

    combined_error <= '0' when error_bus = "0000" else '1';

    process(Clk)
    begin
        if rising_edge(Clk) then
            sync_reg_1 <= Input_Raw;
            sync_reg_2 <= sync_reg_1;

            if Reset = '1' or rdy = '0' then
                phase_acc   <= (others => '0');
                phase_vel   <= (others => '0');
                base_delay  <= INITIAL_DELAY;
                sigma_delta <= X"80";
                locked_int  <= '0';
            else
                if combined_error = '1' then
                    if phase_acc < 32000 then phase_acc <= phase_acc + ACC_STEP; end if;
                    if sigma_delta < 255 then sigma_delta <= sigma_delta + 1; end if;
                else
                    if phase_acc > -32000 then phase_acc <= phase_acc - ACC_STEP; end if;
                    if sigma_delta > 0 then sigma_delta <= sigma_delta - 1; end if;
                end if;

                phase_acc <= phase_acc + signed(phase_vel);

                if phase_acc > ACC_THRESHOLD and base_delay < 31 then
                    base_delay <= base_delay + 1;
                    phase_acc  <= (others => '0');
                    if phase_vel < 127 then phase_vel <= phase_vel + 1; end if;
                elsif phase_acc < -ACC_THRESHOLD and base_delay > 0 then
                    base_delay <= base_delay - 1;
                    phase_acc  <= (others => '0');
                    if phase_vel > -127 then phase_vel <= phase_vel - 1; end if;
                end if;

                phase_vel <= phase_vel - shift_right(phase_vel, 7);

                if abs(phase_acc) < LOCK_LIMIT then
                    locked_int <= '1';
                elsif abs(phase_acc) > UNLOCK_LIMIT then
                    locked_int <= '0';
                end if;
            end if;
        end if;
    end process;

    Signal_Out  <= combined_error;
    Lock_Status <= locked_int;
    Velocity    <= std_logic_vector(phase_vel);

end Refined_Integrated;
