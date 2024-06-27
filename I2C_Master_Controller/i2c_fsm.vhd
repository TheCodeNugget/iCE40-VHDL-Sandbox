library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_fsm is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_slv_addr : in std_logic_vector(9 downto 0);

        -- Config Ports
        i_byte_cnt : in unsigned(7 downto 0);
        i_start : in std_logic;
        i_abort : in std_logic;
        i_addr_mode : in std_logic;
        i_rw_mode : in std_logic;
        i_slv_changed : in std_logic;
        o_start_ack : out std_logic;

        -- Status Ports
        o_config_latch_en : out std_logic;
        o_i2c_busy : out std_logic;
        o_rx_done : out std_logic;
        o_tx_done : out std_logic;
        o_abort_ack : out std_logic;
        o_i2c_sda_en : out std_logic;

        -- I2C detect fsm interfaces
        i_i2c_start_detect : in std_logic;
        i_i2c_stop_detect : in std_logic;
        i_i2c_scl_fall_detect : in std_logic;
        i_arbtr_lost : in std_logic;
        o_en_scl : out std_logic;

        -- RX FIFO Interface
        o_rxfifo_wr_en : out std_logic;

        -- TX FIFO Interface
        i_txfifo_rd_data : in std_logic_vector(7 downto 0);
        o_txfifo_rd_en : out std_logic;

        -- MISC
        i_start_gen_ack : in std_logic;
        o_start_gen_en : out std_logic;
        i_stop_gen_ack : in std_logic;
        o_stop_gen_en : out std_logic;
        o_rx_en : out std_logic;
        o_tx_en : out std_logic;
        o_transaction_complete : out std_logic;
        i_tx_done : in std_logic;
        i_tx_err : in std_logic;
        o_tx_data : out std_logic_vector(7 downto 0);
        o_last_byte : out std_logic;
        i_byte_rx_done : in std_logic
    );
end entity;

architecture rtl of i2c_fsm is

    -- I2C FSM States
    constant c_idle_state           : std_logic_vector(3 downto 0) := b"0000";
    constant c_pol_state            : std_logic_vector(3 downto 0) := b"0001";
    constant c_start_state          : std_logic_vector(3 downto 0) := b"0010";
    constant c_scl_en_state         : std_logic_vector(3 downto 0) := b"0011";
    constant c_slvaddr_msb_state    : std_logic_vector(3 downto 0) := b"0100";
    constant c_slvaddr_lsb_state    : std_logic_vector(3 downto 0) := b"0101";
    constant c_tx_state             : std_logic_vector(3 downto 0) := b"0110";
    constant c_rx_state             : std_logic_vector(3 downto 0) := b"0111";
    constant c_scl_disable_state    : std_logic_vector(3 downto 0) := b"1000";
    constant c_stop_state           : std_logic_vector(3 downto 0) := b"1001";
    constant c_rpt_start_state      : std_logic_vector(3 downto 0) := b"1010";

    -- Config Constants
    constant c_addrmode_7bit    : std_logic := '0';
    constant c_addrmode_10bit   : std_logic := '1';
    constant c_mode_write       : std_logic := '0';
    constant c_mode_read        : std_logic := '1';

    -- Internal Signals
    signal r_curr_state : std_logic_vector(3 downto 0) := b"0000";
    signal r_next_state : std_logic_vector(3 downto 0) := b"0000";
    signal r_bus_busy : std_logic;
    signal r_byte_count : unsigned(7 downto 0);
    signal r_rx_en : std_logic;
    signal r_rpt_start : std_logic;
    signal w_transaction_stop_interrupt : std_logic;

begin

    w_transaction_stop_interrupt <= i_abort or i_tx_err or o_transaction_complete;


    -----------------------------------------------------------
    -- Async Reset
    -----------------------------------------------------------

    rst: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_curr_state <= c_idle_state;
        elsif (rising_edge(i_clk)) then
            r_curr_state <= r_next_state;
        end if;
    end process;

    -----------------------------------------------------------
    -- I2C Control FSM
    -----------------------------------------------------------

    i2c_fsm: process (all) is
    begin
        case (r_curr_state) is
            when c_idle_state => r_next_state <= c_pol_state when i_start;
            when c_pol_state => r_next_state <= c_start_state when r_bus_busy;
            when c_start_state => r_next_state <= c_scl_en_state when i_start_gen_ack;
            when c_scl_en_state => r_next_state <= c_slvaddr_msb_state when i_i2c_scl_fall_detect;

            when c_slvaddr_msb_state =>
                if (i_tx_done) then
                    if (i_arbtr_lost) then
                        r_next_state <= c_idle_state;
                    elsif (w_transaction_stop_interrupt) then
                        r_next_state <= c_scl_disable_state;
                    elsif (i_addr_mode = c_addrmode_10bit) and (r_rpt_start = '0') then
                        r_next_state <= c_slvaddr_lsb_state;
                    elsif ((i_addr_mode = c_addrmode_10bit) and (r_rpt_start = '1')) or ((i_addr_mode = c_addrmode_7bit) and (i_rw_mode = c_mode_read)) then
                        r_next_state <= c_rx_state;
                    else
                        r_next_state <= c_tx_state;
                    end if;
                end if;

            when c_slvaddr_lsb_state =>
                if (i_tx_done) then
                    if (i_arbtr_lost) then
                        r_next_state <= c_idle_state;
                    elsif (w_transaction_stop_interrupt) then
                        r_next_state <= c_scl_disable_state;
                    elsif (i_rw_mode = c_mode_read) then
                        r_next_state <= c_rpt_start_state;
                    else
                        r_next_state <= c_tx_state;
                    end if;
                end if;

            when c_tx_state =>
                if (i_tx_done) then
                    if (i_arbtr_lost) then
                        r_next_state <= c_idle_state;
                    elsif (w_transaction_stop_interrupt) then
                        r_next_state <= c_scl_disable_state;
                    end if;
                end if;

            when c_rpt_start_state =>
                if (o_start_gen_en) then
                    r_next_state <= c_start_state;
                end if;

            when c_rx_state =>
                if (o_rx_done) then
                    if (i_arbtr_lost) then
                        r_next_state <= c_idle_state;
                    elsif (w_transaction_stop_interrupt) then
                        r_next_state <= c_scl_disable_state;
                    end if;
                end if;

            when c_scl_disable_state =>
                if (i_start and (not i_slv_changed)) then
                    r_next_state <= c_start_state;
                else
                    r_next_state <= c_stop_state;
                end if;

            when c_stop_state =>
                if (i_stop_gen_ack) then
                    r_next_state <= c_idle_state;
                end if;

            when others => r_next_state <= c_idle_state;
        end case;
    end process;

    -----------------------------------------------------------
    -- START Generation Enable
    -----------------------------------------------------------

    start_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_start_gen_en <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_curr_state = c_pol_state) then
                o_start_gen_en <= (not r_bus_busy);
            elsif (r_curr_state = c_scl_disable_state) then
                o_start_gen_en <= i_start and (not i_slv_changed);
            elsif (r_curr_state = c_rpt_start_state) then
                o_start_gen_en <= '1';
            else
                o_start_gen_en <= '1';
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- STOP Generation Enable
    -----------------------------------------------------------

    stop_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_stop_gen_en <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_curr_state = c_scl_disable_state) then
                o_stop_gen_en <= (not i_start) or i_slv_changed;
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- SCL Enable
    -----------------------------------------------------------

    scl_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_en_scl <= '0';
        elsif (rising_edge(i_clk)) then
            case (r_curr_state) is
                when c_scl_en_state => o_en_scl <= '1';
                when c_idle_state => o_en_scl <= '0';
                when c_scl_disable_state => o_en_scl <= '0';
                when c_start_state => o_en_scl <= '0';
            end case;
        end if;
    end process;

    -----------------------------------------------------------
    -- Byte Counter
    -----------------------------------------------------------

    byte_counter: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_byte_count <= d"0";
        elsif (rising_edge(i_clk)) then
            if (not o_en_scl) then
                r_byte_count <= d"0";
            elsif (r_byte_count = i_byte_cnt) then
                r_byte_count <= d"0";
            elsif (r_rx_en or o_txfifo_rd_en) then
                r_byte_count <= r_byte_count + 1;
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- Transaction Complete Flag
    -----------------------------------------------------------

    transaction_complete_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_transaction_complete <= '0';
        elsif (rising_edge(i_clk)) then
            if (o_en_scl) then
                if (i_byte_cnt = r_byte_count) then
                    o_transaction_complete <= '1';
                end if;
            else
                o_transaction_complete <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- Last Byte Flag
    -----------------------------------------------------------

    last_byte: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_last_byte <= '0';
        elsif (rising_edge(i_clk)) then
            o_last_byte <= '1' when (i_byte_cnt = r_byte_count) else '0';
        end if;
    end process;

    -----------------------------------------------------------
    -- TX FIFO Read Interface
    -----------------------------------------------------------

    tx_rd_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_txfifo_rd_en <= '0';
        elsif (rising_edge(i_clk)) then
            if (i_tx_done) then
                if (not i_arbtr_lost) then
                    if (not w_transaction_stop_interrupt) then
                        case r_curr_state is
                            when c_slvaddr_msb_state =>
                                if (i_addr_mode = c_addrmode_7bit) then
                                    if (i_rw_mode = c_mode_write) then
                                        o_txfifo_rd_en <= '1';
                                    else
                                        o_txfifo_rd_en <= '0';
                                    end if;
                                else
                                    o_txfifo_rd_en <= '0';
                                end if;

                            when c_slvaddr_lsb_state =>
                                if (i_rw_mode = c_mode_write) then
                                    if (r_curr_state = c_tx_state) then
                                        o_txfifo_rd_en <= '1';
                                    else
                                        o_txfifo_rd_en <= '0';
                                    end if;
                                else
                                    o_txfifo_rd_en <= '0';
                                end if;
                            end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

    tx_data: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_tx_data <= 8b"0";
            r_rpt_start <= '0';
        elsif (rising_edge(i_clk)) then
            case (r_curr_state) is
                when c_slvaddr_msb_state =>
                    if (i_addr_mode = c_addrmode_10bit) then
                        if (r_rpt_start) then
                            o_tx_data <= b"11110" & i_slv_addr(9 downto 8) & '1';
                        else
                            o_tx_data <= b"11110" & i_slv_addr(9 downto 8) & '0';
                        end if;
                    else
                        o_tx_data <= i_slv_addr(6 downto 0) & i_rw_mode;
                    end if;
                    r_rpt_start <= '1';

                when c_slvaddr_lsb_state =>
                    o_tx_data <= i_slv_addr(7 downto 0);
                    r_rpt_start <= '1';

                when c_tx_state =>
                    o_tx_data <= i_txfifo_rd_data;
                    r_rpt_start <= '0';

                when c_rx_state =>
                    o_tx_data <= i_txfifo_rd_data;
                    r_rpt_start <= '0';

                when c_stop_state =>
                    o_tx_data <= i_txfifo_rd_data;
                    r_rpt_start <= '0';
            end case;
        end if;
    end process;

    tx_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_tx_en <= '0';
        elsif (rising_edge(i_clk)) then
            case (r_curr_state) is
                when c_scl_en_state =>
                    o_tx_en <= i_i2c_scl_fall_detect;

                when c_slvaddr_msb_state =>
                    if ((i_tx_done = '1') and (i_addr_mode = c_addrmode_10bit) and (r_next_state = c_rpt_start_state)) then
                        o_tx_en <= '1';
                    else
                        o_tx_en <= '0';
                    end if;

                when c_tx_state =>
                    o_tx_en <= o_txfifo_rd_en;

                when c_rpt_start_state =>
                    o_tx_en <= o_txfifo_rd_en;
            end case;
        end if;
    end process;

    -----------------------------------------------------------
    -- RX FIFO Read Interface
    -----------------------------------------------------------

    rx_wr_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_rxfifo_wr_en <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_curr_state = c_rx_state) then
                o_rxfifo_wr_en <= i_byte_rx_done;
            end if;
        end if;
    end process;

    rx_en: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_rx_en <= '0';
        elsif (rising_edge(i_clk)) then
            o_rx_en <= r_rx_en;
        end if;
    end process;

    rx_en_fsm: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_rx_en <= '0';
        elsif (rising_edge(i_clk)) then
            if ((not i_arbtr_lost) and (not w_transaction_stop_interrupt)) then
                case (r_curr_state) is
                    when c_slvaddr_msb_state =>
                        if ((i_rw_mode = c_mode_read) and (i_tx_done = '1')) then
                            if (i_rw_mode = c_addrmode_7bit) then
                                r_rx_en <= '1';
                            elsif (i_rw_mode = c_addrmode_10bit) then
                                r_rx_en <= r_rpt_start;
                            end if;
                        end if;

                    when c_rx_state =>
                        r_rx_en <= i_byte_rx_done;
                end case;
            else
                r_rx_en <= '0';
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- Status Signal Generation
    -----------------------------------------------------------

    bus_busy_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_bus_busy <= '0';
        elsif (rising_edge(i_clk)) then
            if (i_i2c_start_detect) then
                r_bus_busy <= '1';
            elsif (i_i2c_stop_detect) then
                r_bus_busy <= '0';
            end if;
        end if;
    end process;

    start_ack_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_start_ack <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_curr_state = c_scl_en_state) then
                o_start_ack <= '1';
            else
                o_start_ack <= '0';
            end if;
        end if;
    end process;

    done_flags: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_tx_done <= '0';
            o_rx_done <= '0';
        elsif (rising_edge(i_clk)) then
            case r_curr_state is
                when c_start_state =>
                    o_tx_done <= '0';
                    o_rx_done <= '0';

                when c_scl_disable_state =>
                    if (o_transaction_complete) then
                        o_tx_done <= '1' when (i_rw_mode = c_mode_write) else '0';
                        o_rx_done <= '1' when (i_rw_mode = c_mode_read) else '0';
                    end if;
            end case;
        end if;
    end process;

    abort_ack_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_abort_ack <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_curr_state = c_scl_disable_state) then
                o_abort_ack <= i_abort;
            else
                o_abort_ack <= '0';
            end if;
        end if;
    end process;

    sda_en_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_i2c_sda_en <= '0';
        elsif (rising_edge(i_clk)) then
            case r_curr_state is
                when c_idle_state => o_i2c_sda_en <= '0';
                when c_rx_state => o_i2c_sda_en <= '0';
                when c_pol_state => o_i2c_sda_en <= r_bus_busy;
                when c_scl_en_state => o_i2c_sda_en <= '1';
                when others =>
                    if (i_arbtr_lost) then
                        o_i2c_sda_en <= '0';
                    end if;
            end case;
        end if;
    end process;

    config_latch_en_flag: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_config_latch_en <= '0';
        elsif (rising_edge(i_clk)) then
            case r_curr_state is
                when c_idle_state => o_config_latch_en <= i_start;
                when c_scl_disable_state => o_config_latch_en <= (i_start and (not i_slv_changed));
            end case;
        end if;
    end process;
end architecture;
