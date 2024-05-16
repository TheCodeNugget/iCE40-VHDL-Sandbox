library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_tx is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_en : in std_logic;
        i_scl_falling_edge : in std_logic;
        i_bus_scl : in std_logic;
        i_bus_sda : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_byte_sent : out std_logic;
        o_byte_err : out std_logic;
        o_sda_disable : out std_logic;
        o_byte_tx_sda : out std_logic
    );
end entity;

architecture rtl of i2c_tx is

    constant c_tx_idle : std_logic_vector(3 downto 0) := b"0000";
    constant c_tx_bit0 : std_logic_vector(3 downto 0) := b"0001";
    constant c_tx_bit1 : std_logic_vector(3 downto 0) := b"0010";
    constant c_tx_bit2 : std_logic_vector(3 downto 0) := b"0011";
    constant c_tx_bit3 : std_logic_vector(3 downto 0) := b"0100";
    constant c_tx_bit4 : std_logic_vector(3 downto 0) := b"0101";
    constant c_tx_bit5 : std_logic_vector(3 downto 0) := b"0110";
    constant c_tx_bit6 : std_logic_vector(3 downto 0) := b"0111";
    constant c_tx_bit7 : std_logic_vector(3 downto 0) := b"1000";
    constant c_tx_rack : std_logic_vector(3 downto 0) := b"1001";

    signal r_tx_currState: std_logic_vector(3 downto 0) := b"0000";
    signal r_tx_nextState: std_logic_vector(3 downto 0) := b"0000";

begin

    -----------------------------------------------------------
    -- TX FSM
    -----------------------------------------------------------

    rst: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            r_tx_currState <= c_tx_idle;
        else
            r_tx_currState <= r_tx_nextState;
        end if;
    end process;

    tx_fsm : process(all) is
    begin
        r_tx_nextState <= r_tx_currState;
        if (r_tx_currState = c_tx_idle) then
            if (i_en) then
                r_tx_nextState <= c_tx_bit7;
            end if;
        elsif (i_scl_falling_edge) then
            with r_tx_currState select
                r_tx_nextState <=
                    c_tx_bit6 when c_tx_bit7,
                    c_tx_bit5 when c_tx_bit6,
                    c_tx_bit4 when c_tx_bit5,
                    c_tx_bit3 when c_tx_bit4,
                    c_tx_bit2 when c_tx_bit3,
                    c_tx_bit1 when c_tx_bit2,
                    c_tx_bit0 when c_tx_bit1,
                    c_tx_rack when c_tx_bit0,
                    c_tx_idle when c_tx_rack,
                    c_tx_idle when others;
        end if;
    end process;

    -----------------------------------------------------------
    -- I2C RX DATA
    -----------------------------------------------------------

    tx_data: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            o_byte_tx_sda <= '1';
        else
            with r_tx_currState select
                o_byte_tx_sda <=
                    '1' when c_tx_idle,
                    i_data(7) when c_tx_bit7,
                    i_data(6) when c_tx_bit6,
                    i_data(5) when c_tx_bit5,
                    i_data(4) when c_tx_bit4,
                    i_data(3) when c_tx_bit3,
                    i_data(2) when c_tx_bit2,
                    i_data(1) when c_tx_bit1,
                    i_data(0) when c_tx_bit0,
                    '1' when c_tx_rack,
                    '1' when others;
        end if;
    end process;

    -----------------------------------------------------------
    -- I2C SDA Driver Disable for Sampling Receiver ACK
    -----------------------------------------------------------

    sda_dis: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            o_sda_disable <= '0';
        else
            o_sda_disable <= '1' when (r_tx_currState = c_tx_rack) else '0';
        end if;
    end process;

    -----------------------------------------------------------
    -- Raise Error Flag if ACK not Present
    -----------------------------------------------------------

    tx_err: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            o_byte_err <= '0';
        elsif (r_tx_currState = c_tx_rack) and (i_bus_scl = '1') and (i_bus_sda = '1') then
            o_byte_err <= '1';
        elsif (o_byte_sent = '1') then
            o_byte_err <= '0';
        end if;
    end process;

    -----------------------------------------------------------
    -- Raise Done Flag
    -----------------------------------------------------------

    tx_done: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            o_byte_sent <= '0';
        else
            if (r_tx_currState = c_tx_rack) and (i_scl_falling_edge = '1') then
                o_byte_sent <= '1';
            else
                o_byte_sent <= '0';
            end if;
        end if;
    end process;
end architecture;
