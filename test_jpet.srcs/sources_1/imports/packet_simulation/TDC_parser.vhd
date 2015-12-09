-- This source file was created for J-PET project in WFAIS (Jagiellonian University in Cracow)
-- License for distribution outside WFAIS UJ and J-PET project is GPL v 3
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity TDC_parser is
	port(
	    clock:in std_logic;
		in_data:in std_logic;
		dataWORD:in std_logic_vector(31 downto 0);
		channel_offset:in std_logic_vector(15 downto 0);
	    eventID: in std_logic_vector(31 downto 0);
		triggerID: in std_logic_vector(31 downto 0);
		out_data: out std_logic;
		time_isrising:out std_logic;
		time_channel: out std_logic_vector(15 downto 0);
		time_epoch: out std_logic_vector(27 downto 0);
		time_fine: out std_logic_vector(9 downto 0);
		time_coasser:out std_logic_vector(10 downto 0)
	);
end TDC_parser;

architecture Behavioral of TDC_parser is
    signal saved_channel_offset: std_logic_vector(15 downto 0);
    signal saved_eventID: std_logic_vector(31 downto 0);
    signal saved_triggerID: std_logic_vector(31 downto 0);
    signal reset:std_logic:='0';
    signal parse:std_logic:='0';
    signal offset:integer:=0;
    type tdc_state is(IDLE,HEADER_READ,EPOCH_READ);
    signal current_tdc_state,next_tdc_state:tdc_state:=IDLE;
begin

state_change:process(reset,in_data)
begin
    if rising_edge(clock) then
        if reset='1' then
            current_tdc_state<=IDLE;
        elsif in_data='0' then
            current_tdc_state<=next_tdc_state;
        end if;
    end if;
end process state_change;

trigger_change_check:process(clock)
begin
    if rising_edge(clock) then
        if(not(saved_eventID=eventID))or
            (not(saved_triggerID=triggerID))or
            (not(saved_channel_offset=channel_offset))then
            reset<='1';
        end if;
        if(reset='1')and(current_tdc_state=IDLE)then
            saved_eventID<=eventID;
            saved_triggerID<=triggerID;
            saved_channel_offset<=channel_offset;
            reset<='0';
        end if;
    end if;
end process trigger_change_check;

in_data_to_parse:process(in_data, clock)
begin
    if rising_edge(clock) then
        parse <= in_data;
    end if;
end process in_data_to_parse;

state_machine:process(parse, clock)
    variable channel:integer:=0;
begin
    if rising_edge(clock) then
        if parse = '1' then
            case current_tdc_state is
            when IDLE => 
                if(dataWORD(31)='0')and(dataWORD(30)='0')and(dataWORD(29)='1')then
                    next_tdc_state<=HEADER_READ;
                    for i in 15 downto 0 loop
                        if dataWORD(i)='1' then
                            next_tdc_state<=IDLE;
                        end if;
                    end loop;
                    offset<=0;
                    for i in 15 downto 0 loop
                        offset<=offset*2;
                        if channel_offset(i)='1' then
                            offset<=offset+1;
                        end if;
                    end loop;
                end if;
            when HEADER_READ => 
                if(dataWORD(31)='0')and(dataWORD(30)='1')and(dataWORD(29)='1')then
                    next_tdc_state<=EPOCH_READ;
                end if;
            when EPOCH_READ => 
                if dataWORD(31)='1' then
                    for i in 9 downto 0 loop
                        time_fine(i)<=dataWORD(i+12);
                    end loop;
                    for i in 10 downto 0 loop
                        time_coasser(i)<=dataWORD(i);
                    end loop;
                    time_isrising<=dataWORD(11);
                    channel:=0;
                    for i in 6 downto 0 loop
                        channel:=channel*2;
                        if dataWORD(i+22)='1'then
                            channel:=channel+1;
                        end if;
                    end loop;
                    channel:=channel+offset;
                    for i in 0 to 15 loop
                        if channel mod 2 = 1 then
                            time_channel(i)<='1';
                        else
                            time_channel(i)<='0';
                        end if;
                        channel:=channel/2;
                    end loop;
                    out_data<='1';
                end if;
            end case;
            if(dataWORD(31)='0')and(dataWORD(30)='1')and(dataWORD(29)='1')then
                for i in 27 downto 0 loop
                    time_epoch(i)<=dataWORD(i);
                end loop;
            end if;
        elsif parse = '0' then
            out_data<='0';
        end if;
    end if;
end process state_machine;
end Behavioral;
