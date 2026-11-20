# Icarus Verilog simulation.
#   make             run all testbenches
#   make net         run one; waveform written to build/<testbench>.vcd
#   make clean

RTL   := ../rtl
TOOLS := ../tools
BUILD := build
IV    := iverilog -g2012 -Wall -Wno-timescale

UART_SRCS := $(RTL)/clk_div.v $(RTL)/uart_rx.v $(RTL)/uart_tx.v $(RTL)/fifo.v $(RTL)/uart.v
NET_SRCS  := $(RTL)/pkt_buf.v $(RTL)/slip_rx.v $(RTL)/slip_tx.v $(RTL)/pkt_echo.v \
             $(RTL)/ip_icmp.v $(RTL)/net_top.v

.PHONY: all rx loopback slip echo ping vectors clean
all: rx loopback slip echo ping

rx: | $(BUILD)
	$(IV) -o $(BUILD)/tb_uart_rx.vvp tb_uart_rx.v $(RTL)/uart_rx.v $(RTL)/clk_div.v
	cd $(BUILD) && vvp -n tb_uart_rx.vvp

loopback: | $(BUILD)
	$(IV) -o $(BUILD)/tb_uart_loopback.vvp tb_uart_loopback.v $(UART_SRCS) $(RTL)/uart_loopback_top.v
	cd $(BUILD) && vvp -n tb_uart_loopback.vvp

slip: | $(BUILD)
	$(IV) -o $(BUILD)/tb_slip_rx.vvp tb_slip_rx.v $(RTL)/pkt_buf.v $(RTL)/slip_rx.v
	cd $(BUILD) && vvp -n tb_slip_rx.vvp

# Full stack, pkt_echo processor: SLIP framing edge cases
echo: vectors
	$(IV) -DECHO_MODE -o $(BUILD)/tb_net_echo.vvp tb_net_top.v $(UART_SRCS) $(NET_SRCS)
	cd $(BUILD) && vvp -n tb_net_echo.vvp

# Full stack, ip_icmp processor: the ping milestone
ping: vectors
	$(IV) -o $(BUILD)/tb_net_ping.vvp tb_net_top.v $(UART_SRCS) $(NET_SRCS)
	cd $(BUILD) && vvp -n tb_net_ping.vvp

vectors: | $(BUILD)
	python3 $(TOOLS)/gen_net_vectors.py $(BUILD)

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
