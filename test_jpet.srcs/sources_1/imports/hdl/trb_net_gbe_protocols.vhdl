library ieee;
use ieee.std_logic_1164.all;
USE IEEE.numeric_std.ALL;

package trb_net_gbe_protocols is

	-- PROTOCOLS DEFINITIONS
	-- 1. ARP
	-- 2. DHCP
	-- 3. Ping
	-- 4. TcpForward
	-- 5. DataTX (tx only)
	-- 6. DataRX

	constant c_MAX_FRAME_TYPES   : integer range 1 to 16 := 2;
	constant c_MAX_PROTOCOLS     : integer range 1 to 16 := 4;
	constant c_MAX_IP_PROTOCOLS  : integer range 1 to 16 := 3;
	constant c_MAX_UDP_PROTOCOLS : integer range 1 to 16 := 4;
	constant c_MAX_TCP_PROTOCOLS : integer range 1 to 16 := 2;

	type frame_types_a is array (c_MAX_FRAME_TYPES - 1 downto 0) of std_logic_vector(15 downto 0);
	constant FRAME_TYPES : frame_types_a := (x"0800", x"0806");
	-- IPv4, ARP

	type ip_protos_a is array (c_MAX_IP_PROTOCOLS - 1 downto 0) of std_logic_vector(7 downto 0);
	constant IP_PROTOCOLS : ip_protos_a := (x"11", x"01", x"06");
	-- UDP, ICMP, TCP

	-- this are the destination ports of the incoming packet
	type udp_protos_a is array (c_MAX_UDP_PROTOCOLS - 1 downto 0) of std_logic_vector(15 downto 0);
	constant UDP_PROTOCOLS : udp_protos_a := (x"0044", x"61a8", x"61a8", x"2710");
	-- DHCP client, Data

	type tcp_protocols_a is array (c_MAX_TCP_PROTOCOLS - 1 downto 0) of std_logic_vector(15 downto 0);
	constant TCP_PROTOCOLS : tcp_protocols_a := (x"1700", x"0050");
	-- Telnet, HTTP

end package;
