library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_rx is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_en : in std_logic;
        i_complete : in std_logic;
        i_scl_falling_edge : in std_logic;
        i_bus_scl : in std_logic;
        i_bus_sda : in std_logic;
        o_byte_rdy : out std_logic;
        o_sda_en : out std_logic;
        o_rx_ack_sda : out std_logic;
        o_data : out std_logic_vector(7 downto 0)
    );
end i2c_rx;

architecture rtl of i2c_rx is

    constant c_rx_idle : std_logic_vector(3 downto 0) := b"0000";
    constant c_rx_bit0 : std_logic_vector(3 downto 0) := b"0001";
    constant c_rx_bit1 : std_logic_vector(3 downto 0) := b"0010";
    constant c_rx_bit2 : std_logic_vector(3 downto 0) := b"0011";
    constant c_rx_bit3 : std_logic_vector(3 downto 0) := b"0100";
    constant c_rx_bit4 : std_logic_vector(3 downto 0) := b"0101";
    constant c_rx_bit5 : std_logic_vector(3 downto 0) := b"0110";
    constant c_rx_bit6 : std_logic_vector(3 downto 0) := b"0111";
    constant c_rx_bit7 : std_logic_vector(3 downto 0) := b"1000";
    constant c_rx_wack : std_logic_vector(3 downto 0) := b"1001";

    signal r_rx_currState: std_logic_vector(3 downto 0) := b"0000";
    signal r_rx_nextState: std_logic_vector(3 downto 0) := b"0000";

begin

    -----------------------------------------------------------
    -- RX FSM
    -----------------------------------------------------------

    rst : process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            r_rx_currState <= c_rx_idle;
        else
            r_rx_currState <= r_rx_nextState;
        end if;
    end process;

    rx_fsm : process(all)
    begin
        r_rx_nextState <= r_rx_currState;
        if (r_rx_currState = c_rx_idle) then
            if (i_en) then
                r_rx_nextState <= c_rx_bit7;
            end if;
        elsif (i_scl_falling_edge) then
            with r_rx_currState select
                r_rx_nextState <=
                    c_rx_bit6 when c_rx_bit7,
                    c_rx_bit5 when c_rx_bit6,
                    c_rx_bit4 when c_rx_bit5,
                    c_rx_bit3 when c_rx_bit4,
                    c_rx_bit2 when c_rx_bit3,
                    c_rx_bit1 when c_rx_bit2,
                    c_rx_bit0 when c_rx_bit1,
                    c_rx_wack when c_rx_bit0,
                    c_rx_idle when c_rx_wack,
                    c_rx_idle when others;
        end if;
    end process;

    -----------------------------------------------------------
    -- I2C RX DATA
    -----------------------------------------------------------

    rx_data: process (all) is
    begin
        if (i_bus_scl) then
            case r_rx_currState is
                when c_rx_bit7 => o_data(7) <= i_bus_sda;
                when c_rx_bit6 => o_data(6) <= i_bus_sda;
                when c_rx_bit5 => o_data(5) <= i_bus_sda;
                when c_rx_bit4 => o_data(4) <= i_bus_sda;
                when c_rx_bit3 => o_data(3) <= i_bus_sda;
                when c_rx_bit2 => o_data(2) <= i_bus_sda;
                when c_rx_bit1 => o_data(1) <= i_bus_sda;
                when c_rx_bit0 => o_data(0) <= i_bus_sda;
            end case;
        end if;
    end process;

    -----------------------------------------------------------
    -- I2C SDA Driver enable for sending ACK to Transmitter
    -----------------------------------------------------------

    sda_en: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            o_sda_en <= '1';
        else
            o_sda_en <= '1' when r_rx_currState = c_rx_wack else '0';
        end if;
    end process;

    -----------------------------------------------------------
    -- RX Ack Gen
    -----------------------------------------------------------

    tx_ack: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            o_rx_ack_sda <= '1';
        else
            if (r_rx_currState = c_rx_wack) then
                if (not i_bus_scl) then
                    o_rx_ack_sda <= (i_complete);
                end if;
            else
                o_rx_ack_sda <= '1';
            end if;
        end if;
    end process;

    byte_flag: process (rising_edge(i_clk), rising_edge(i_rst)) is
    begin
        if (i_rst) then
            o_byte_rdy <= '0';
        else
            if (r_rx_currState = c_rx_wack) and (i_scl_falling_edge = '1') then
                o_byte_rdy <= '1';
            else
                o_byte_rdy <= '0';
            end if;
        end if;
    end process;

end architecture;
