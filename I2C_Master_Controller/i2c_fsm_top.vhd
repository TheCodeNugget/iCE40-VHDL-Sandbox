library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity i2c_fsm_top is
    port (
        i_clk           : in std_logic;
        i_rst           : in std_logic;
        i_bus_sda       : in std_logic;
        i_bus_scl       : in std_logic;

        -- Configuration Ports
        i_scl_timeout   : in std_logic;
        i_slv_addr_reg  : in std_logic_vector(9 downto 0);
        i_byte_cnt_reg  : in unsigned(7 downto 0);
        i_clk_div       : in std_logic_vector(7 downto 0);
        i_config_reg    : in std_logic_vector(5 downto 0);
        i_mode_reg      : in std_logic_vector(7 downto 0);

        o_start_ack     : out std_logic;
        o_tx_en         : out std_logic;
        o_i2c_sda_en    : out std_logic;
        o_i2c_txdata_sda: out std_logic;

        o_scl_divcnt    : out std_logic_vector(10 downto 0);
        o_bps_reg       : out std_logic_vector(1 downto 0);

        -- I2C Detector FSM Ports
        i_arbtr_lost    : in std_logic;

        i_scl_falling_edge   : in std_logic;
        o_scl_en        : out std_logic;

        o_start_en      : out std_logic;
        i_start_ack     : in std_logic;
        i_start_detect  : in std_logic;

        o_stop_en       : out std_logic;
        i_stop_ack      : in std_logic;
        i_stop_detect   : in std_logic;

        o_int_out       : out std_logic;
        o_cmd_stat_reg  : out std_logic_vector(7 downto 0);

        -- RX FIFO Ports
        o_rxfifo_wr_en  : out std_logic;
        o_rxfifo_wr_data: out std_logic_vector(7 downto 0);

        -- RX FIFO Ports
        i_txfifo_rd_data: in std_logic_vector(7 downto 0);
        o_txfifo_rd_en  : out std_logic
    );
end entity;

architecture rtl of i2c_fsm_top is

    signal w_tx_data      : std_logic_vector(7 downto 0);
    signal w_tx_en        : std_logic;
    signal w_rx_en        : std_logic;
    signal w_last_byte    : std_logic;
    signal w_byte_tx_sda  : std_logic;
    signal w_byte_tx_done : std_logic;
    signal w_byte_tx_error: std_logic;
    signal w_byte_rx_done : std_logic;
    signal w_sda_enable   : std_logic;
    signal w_sda_disable  : std_logic;
    signal w_rx_ack_sda   : std_logic;
    signal w_i2c_sda_en   : std_logic;
    signal w_transaction_complete : std_logic;

    signal w_i2c_busy : std_logic;
    signal w_tx_done  : std_logic;
    signal w_rx_done  : std_logic;
    signal w_tx_err   : std_logic;
    signal w_rx_err   : std_logic;
    signal w_abort_ack: std_logic;

    signal r_start_reg1   : std_logic;
    signal r_start_reg2   : std_logic;
    signal r_abort_reg1   : std_logic;
    signal r_abort_reg2   : std_logic;
    signal r_intr_clr_reg : std_logic;
    signal r_intr_clr_reg1 : std_logic;
    signal r_intr_clr_reg2 : std_logic;

    signal r_tx_done_reg  : std_logic;
    signal r_tx_done_d1   : std_logic;
    signal r_rx_done_reg  : std_logic;
    signal r_rx_done_d1   : std_logic;
    signal r_tx_err_reg   : std_logic;
    signal r_tx_err_d1    : std_logic;
    signal r_rx_err_reg   : std_logic;
    signal r_rx_err_d1    : std_logic;
    signal r_abort_ack_d1 : std_logic;
    signal r_abort_ack_reg : std_logic;
    signal r_arbtr_lost_d1 : std_logic;
    signal r_scl_timeout_d1 : std_logic;
    signal r_arbtr_lost_reg : std_logic;
    signal r_scl_timeout_reg : std_logic;

    signal w_interrupt_clear    : std_logic;
    signal w_config_latch_en    : std_logic;
    signal w_interrupt_reset    : std_logic;

    signal r_slave_changed  : std_logic;

    signal w_abort_reg : std_logic;
    signal w_start_reg : std_logic;
    signal w_start_bit : std_logic;
    signal w_start_ack : std_logic;
    signal w_start_rst : std_logic;
    signal r_adr_mode  : std_logic;
    signal r_rw_mode   : std_logic;
    signal r_ack_mode  : std_logic;
    signal r_txintr_en : std_logic;
    signal r_rxintr_en : std_logic;
    signal r_config_start_reg : std_logic;
    signal r_config_reg : std_logic_vector(5 downto 0);
    signal r_byte_count : unsigned(7 downto 0);
    signal r_slave_addr : std_logic_vector(9 downto 0);

begin

    o_tx_en <= w_tx_en;
    o_start_ack <= w_start_ack;

    i2c_fsm_inst: entity work.i2c_fsm
    port map (
        i_clk                  => i_clk,
        i_rst                  => i_rst,
        i_slv_addr             => r_slave_addr,
        i_byte_cnt             => r_byte_count,
        i_start                => w_start_reg,
        i_abort                => w_abort_reg,
        i_addr_mode            => r_adr_mode,
        i_rw_mode              => r_rw_mode,
        i_slv_changed          => r_slave_changed,
        o_start_ack            => w_start_ack,
        o_config_latch_en      => w_config_latch_en,
        o_i2c_busy             => w_i2c_busy,
        o_rx_done              => w_rx_done,
        o_tx_done              => w_tx_done,
        o_abort_ack            => w_abort_ack,
        o_i2c_sda_en           => w_i2c_sda_en,
        i_i2c_start_detect     => i_start_detect,
        i_i2c_stop_detect      => i_stop_detect,
        i_i2c_scl_fall_detect  => i_scl_falling_edge,
        i_arbtr_lost           => i_arbtr_lost,
        o_en_scl               => o_scl_en,
        o_rxfifo_wr_en         => o_rxfifo_wr_en,
        i_txfifo_rd_data       => i_txfifo_rd_data,
        o_txfifo_rd_en         => o_txfifo_rd_en,
        i_start_gen_ack        => i_start_ack,
        o_start_gen_en         => o_start_en,
        i_stop_gen_ack         => i_stop_ack,
        o_stop_gen_en          => o_stop_en,
        o_rx_en                => w_rx_en,
        o_tx_en                => w_tx_en,
        o_transaction_complete => w_transaction_complete,
        i_tx_done              => w_tx_done,
        i_tx_err               => w_tx_err,
        o_tx_data              => w_tx_data,
        o_last_byte            => w_last_byte,
        i_byte_rx_done         => w_byte_tx_done
    );

    i2c_tx_inst: entity work.i2c_tx
    port map (
        i_clk              => i_clk,
        i_rst              => i_rst,
        i_en               => w_tx_en,
        i_scl_falling_edge => i_scl_falling_edge,
        i_bus_scl          => i_bus_scl,
        i_bus_sda          => i_bus_sda,
        i_tx_data          => w_tx_data,
        o_byte_tx_done     => w_byte_tx_done,
        o_byte_tx_err      => w_byte_tx_error,
        o_sda_disable      => w_sda_disable,
        o_byte_tx_sda      => w_byte_tx_sda
    );

    i2c_rx_inst: entity work.i2c_rx
    port map (
        i_clk                  => i_clk,
        i_rst                  => i_rst,
        i_en                   => w_rx_en,
        i_transaction_complete => w_transaction_complete,
        i_scl_falling_edge     => i_scl_falling_edge,
        i_bus_scl              => i_bus_scl,
        i_bus_sda              => i_bus_sda,
        o_byte_rx_done         => w_byte_rx_done,
        o_sda_en               => w_sda_enable,
        o_rx_ack_sda           => w_rx_ack_sda,
        o_rx_data              => o_rxfifo_wr_data
    );

    o_i2c_txdata_sda <= w_rx_ack_sda and w_byte_tx_sda;
    o_i2c_sda_en <= (w_i2c_sda_en and (not w_sda_disable)) or w_sda_enable;
    w_tx_err <= (not r_rw_mode) and w_byte_tx_error;
    w_rx_err <= r_rw_mode and w_byte_tx_error;

    intr_cnfg_load: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_txintr_en <= '0';
            r_rxintr_en <= '0';
        elsif (rising_edge(i_clk)) then
            if (w_config_latch_en) then
                r_txintr_en <= i_config_reg(3);
                r_rxintr_en <= i_config_reg(2);
            end if;
        end if;
    end process;

    reg1_load: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_start_reg1    <= '0';
            r_abort_reg1    <= '0';
            r_intr_clr_reg  <= '0';
        elsif (rising_edge(i_clk)) then
            r_start_reg1    <= i_config_reg(4);
            r_abort_reg1    <= i_config_reg(1);
            r_intr_clr_reg  <= i_config_reg(0);
        end if;
    end process;

    reg2_load: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_start_reg2    <= '0';
            r_abort_reg2    <= '0';
            r_intr_clr_reg1 <= '0';
            r_intr_clr_reg2 <= '0';
        elsif (rising_edge(i_clk)) then
            r_start_reg2    <= r_start_reg1;
            r_abort_reg2    <= r_abort_reg1;
            r_intr_clr_reg1 <= r_intr_clr_reg;
            r_intr_clr_reg2 <= r_intr_clr_reg1;
        end if;
    end process;

    w_start_reg <= r_start_reg2;
    w_abort_reg <= r_abort_reg2;
    w_interrupt_clear <= r_intr_clr_reg1 and (not r_intr_clr_reg2);

    delay_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_tx_done_d1     <= '0';
            r_rx_done_d1     <= '0';
            r_tx_err_d1      <= '0';
            r_rx_err_d1      <= '0';
            r_abort_ack_d1   <= '0';
            r_arbtr_lost_d1  <= '0';
            r_scl_timeout_d1 <= '0';
        elsif (rising_edge(i_clk)) then
            r_tx_done_d1     <= w_tx_done;
            r_rx_done_d1     <= w_rx_done;
            r_tx_err_d1      <= w_tx_err;
            r_rx_err_d1      <= w_rx_err;
            r_abort_ack_d1   <= w_abort_ack;
            r_arbtr_lost_d1  <= i_arbtr_lost;
            r_scl_timeout_d1 <= i_scl_timeout;
        end if;
    end process;

    tx_done_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_tx_done_reg <= '0';
        elsif (rising_edge(i_clk)) then
            if(w_interrupt_clear) then
                r_tx_done_reg <= '0';
            elsif (w_tx_done and (not r_tx_done_d1)) then
                r_tx_done_reg <= '1';
            end if;
        end if;
    end process;

    rx_done_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_rx_done_reg <= '0';
        elsif (rising_edge(i_clk)) then
            if(w_interrupt_clear) then
                r_rx_done_reg <= '0';
            elsif (w_rx_done and (not r_rx_done_d1)) then
                r_rx_done_reg <= '1';
            end if;
        end if;
    end process;

    tx_err_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_tx_err_reg <= '0';
        elsif (rising_edge(i_clk)) then
            if(w_interrupt_clear) then
                r_tx_err_reg <= '0';
            elsif (w_tx_err and (not r_tx_err_d1)) then
                r_tx_err_reg <= '1';
            end if;
        end if;
    end process;

    rx_err_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_rx_err_reg <= '0';
        elsif (rising_edge(i_clk)) then
            if(w_interrupt_clear) then
                r_rx_err_reg <= '0';
            elsif (w_rx_err and (not r_rx_err_d1)) then
                r_rx_err_reg <= '1';
            end if;
        end if;
    end process;

    abort_ack_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_abort_ack_reg <= '0';
        elsif (rising_edge(i_clk)) then
            if(w_interrupt_clear) then
                r_abort_ack_reg <= '0';
            elsif (w_abort_ack and (not r_abort_ack_d1)) then
                r_abort_ack_reg <= '1';
            end if;
        end if;
    end process;

    arbtr_lost_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_arbtr_lost_reg <= '0';
        elsif (rising_edge(i_clk)) then
            if(w_interrupt_clear) then
                r_arbtr_lost_reg <= '0';
            elsif (i_arbtr_lost and (not r_arbtr_lost_d1)) then
                r_arbtr_lost_reg <= '1';
            end if;
        end if;
    end process;

    scl_timeout_reg: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_scl_timeout_reg <= '0';
        elsif (rising_edge(i_clk)) then
            if(w_interrupt_clear) then
                r_scl_timeout_reg <= '0';
            elsif (i_scl_timeout and (not r_scl_timeout_d1)) then
                r_scl_timeout_reg <= '1';
            end if;
        end if;
    end process;

    o_cmd_stat_reg <= w_i2c_busy & r_tx_done_reg & r_rx_done_reg & r_tx_err_reg & r_rx_err_reg & r_abort_ack_reg & r_arbtr_lost_reg & r_scl_timeout_reg;

    slv_addr_latch: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_slave_addr <= 10b"0";
            r_byte_count <= 8b"0";
        elsif (rising_edge(i_clk)) then
            if (w_config_latch_en) then
                r_slave_addr <= i_slv_addr_reg;
                r_byte_count <= i_byte_cnt_reg;
            end if;
        end if;
    end process;

    o_scl_divcnt <= i_mode_reg(2 downto 0) & i_clk_div;

    slv_change: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            r_slave_changed <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_slave_addr = i_slv_addr_reg) then
                r_slave_changed <= '0';
            else
                r_slave_changed <= '1';
            end if;
        end if;
    end process;

    mode_latch: process (all) is
    begin
        if (i_rst) then
            o_bps_reg   <= 2b"0";
            r_adr_mode  <= '0';
            r_ack_mode  <= '0';
            r_rw_mode   <= '0';
        elsif (rising_edge(i_clk)) then
            if (w_config_latch_en) then
                o_bps_reg   <= i_mode_reg(7) & i_mode_reg(6);
                r_adr_mode  <= i_mode_reg(5);
                r_ack_mode  <= i_mode_reg(4);
                r_rw_mode   <= i_mode_reg(3);
            end if;
        end if;
    end process;

    -----------------------------------------------------------
    -- Interrupt Logic
    -----------------------------------------------------------

    w_interrupt_reset <= i_rst or w_interrupt_clear or r_intr_clr_reg or r_intr_clr_reg1 or r_intr_clr_reg2 or i_config_reg(1);

    interrupt_handler: process (i_clk, i_rst) is
    begin
        if (i_rst) then
            o_int_out <= '0';
        elsif (rising_edge(i_clk)) then
            if (r_txintr_en or r_rxintr_en) then
                if ((((r_tx_done_reg) and w_i2c_busy) or r_tx_err_reg) or (((r_rx_done_reg and w_i2c_busy) or r_rx_err_reg))) then
                    o_int_out <= '1';
                end if;
                if (r_abort_ack_reg or r_arbtr_lost_reg or r_scl_timeout_reg) then
                    o_int_out <= '1';
                end if;
            end if;
        end if;
    end process;
end architecture;
