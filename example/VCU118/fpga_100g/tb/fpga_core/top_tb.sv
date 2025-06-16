`timescale 1ns/1ps

// Simple simulation testbench for fpga_core
// Generates the 4 control flow packets described in the README:
// 1) open QP
// 2) modify QP to RTS
// 3) start data transfer
// 4) close QP
//
// Destination MAC is 02:00:00:00:00:00 and packets are injected directly on the
// QSFP AXI stream as Ethernet frames decoded by eth_axis_rx

module top_tb;

  localparam DATA_WIDTH = 512;
  localparam KEEP_WIDTH = DATA_WIDTH/8;

  // core clocks
  localparam real CLK_PERIOD = 1000.0/322.625;
  localparam real DRP_PERIOD = 1000.0/125.0;

  reg clk = 0;
  reg drp_clk = 0;
  reg rst = 1;

  always #(CLK_PERIOD/2) clk = ~clk;
  always #(DRP_PERIOD/2) drp_clk = ~drp_clk;

  initial begin
    #40 rst = 0;
  end

  // QSFP RX AXI stream directly driven by the testbench
  reg [DATA_WIDTH-1:0] rx_axis_tdata = 0;
  reg [KEEP_WIDTH-1:0] rx_axis_tkeep = 0;
  reg rx_axis_tvalid = 0;
  reg rx_axis_tlast  = 0;
  reg rx_axis_tuser  = 0;


  // TX path from fpga_core through FIFO
  wire [DATA_WIDTH-1:0] qsfp1_tx_axis_tdata;
  wire [KEEP_WIDTH-1:0] qsfp1_tx_axis_tkeep;
  wire qsfp1_tx_axis_tvalid;
  wire qsfp1_tx_axis_tready;
  wire qsfp1_tx_axis_tlast;
  wire qsfp1_tx_axis_tuser;

  wire [DATA_WIDTH-1:0] fifo_tx_axis_tdata;
  wire [KEEP_WIDTH-1:0] fifo_tx_axis_tkeep;
  wire fifo_tx_axis_tvalid;
  wire fifo_tx_axis_tlast;
  wire fifo_tx_axis_tuser;


  // core instance
  fpga_core core_inst (
      .clk(clk),
      .rst(rst),
      .btnu(1'b0),
      .btnl(1'b0),
      .btnd(1'b0),
      .btnr(1'b0),
      .btnc(1'b0),
      .sw(4'd0),
      .led(),

      .qsfp1_tx_axis_tdata(qsfp1_tx_axis_tdata),
      .qsfp1_tx_axis_tkeep(qsfp1_tx_axis_tkeep),
      .qsfp1_tx_axis_tvalid(qsfp1_tx_axis_tvalid),
      .qsfp1_tx_axis_tready(qsfp1_tx_axis_tready),
      .qsfp1_tx_axis_tlast(qsfp1_tx_axis_tlast),
      .qsfp1_tx_axis_tuser(qsfp1_tx_axis_tuser),
      .qsfp1_tx_enable(),

      .qsfp1_rx_axis_tdata(rx_axis_tdata),
      .qsfp1_rx_axis_tkeep(rx_axis_tkeep),
      .qsfp1_rx_axis_tvalid(rx_axis_tvalid),
      .qsfp1_rx_axis_tlast(rx_axis_tlast),
      .qsfp1_rx_axis_tuser(rx_axis_tuser),
      .qsfp1_rx_enable(),
      .qsfp1_rx_status(1'b0),

      .qsfp1_drp_clk(drp_clk),
      .qsfp1_drp_rst(rst),
      .qsfp1_drp_addr(),
      .qsfp1_drp_di(),
      .qsfp1_drp_en(),
      .qsfp1_drp_we(),
      .qsfp1_drp_do(16'd0),
      .qsfp1_drp_rdy(1'b0),

      .qsfp2_tx_axis_tdata(),
      .qsfp2_tx_axis_tkeep(),
      .qsfp2_tx_axis_tvalid(),
      .qsfp2_tx_axis_tready(1'b1),
      .qsfp2_tx_axis_tlast(),
      .qsfp2_tx_axis_tuser(),
      .qsfp2_tx_enable(),
      .qsfp2_rx_axis_tdata(512'd0),
      .qsfp2_rx_axis_tkeep(64'd0),
      .qsfp2_rx_axis_tvalid(1'b0),
      .qsfp2_rx_axis_tlast(1'b0),
      .qsfp2_rx_axis_tuser(1'b0),
      .qsfp2_drp_clk(drp_clk),
      .qsfp2_drp_rst(rst),
      .qsfp2_drp_addr(),
      .qsfp2_drp_di(),
      .qsfp2_drp_en(),
      .qsfp2_drp_we(),
      .qsfp2_drp_do(16'd0),
      .qsfp2_drp_rdy(1'b0),
      .qsfp2_rx_enable(),
      .qsfp2_rx_status(1'b0)
  );

  // asynchronous FIFO from core to CMAC
  axis_async_fifo #(
      .DEPTH(4200),
      .DATA_WIDTH(DATA_WIDTH),
      .KEEP_ENABLE(1),
      .KEEP_WIDTH(KEEP_WIDTH),
      .ID_ENABLE(0),
      .DEST_ENABLE(0),
      .USER_ENABLE(1),
      .USER_WIDTH(1),
      .FRAME_FIFO(1),
      .USER_BAD_FRAME_VALUE(1'b1),
      .USER_BAD_FRAME_MASK(1'b1)
  ) tx_fifo_stack2cmac (
      .s_clk              (clk),
      .s_rst              (rst),
      .s_axis_tdata       (qsfp1_tx_axis_tdata),
      .s_axis_tkeep       (qsfp1_tx_axis_tkeep),
      .s_axis_tvalid      (qsfp1_tx_axis_tvalid),
      .s_axis_tready      (qsfp1_tx_axis_tready),
      .s_axis_tlast       (qsfp1_tx_axis_tlast),
      .s_axis_tid         (0),
      .s_axis_tdest       (0),
      .s_axis_tuser       (qsfp1_tx_axis_tuser),

      .m_clk              (clk),
      .m_rst              (rst),
      .m_axis_tdata       (fifo_tx_axis_tdata),
      .m_axis_tkeep       (fifo_tx_axis_tkeep),
      .m_axis_tvalid      (fifo_tx_axis_tvalid),
      .m_axis_tready      (1'b1),
      .m_axis_tlast       (fifo_tx_axis_tlast),
      .m_axis_tid         (),
      .m_axis_tdest       (),
      .m_axis_tuser       (fifo_tx_axis_tuser),

      .s_pause_req(1'b0),
      .s_pause_ack(),
      .m_pause_req(1'b0),
      .m_pause_ack(),
      .s_status_depth(),
      .s_status_depth_commit(),
      .s_status_overflow(),
      .s_status_bad_frame(),
      .s_status_good_frame(),
      .m_status_depth(),
      .m_status_depth_commit(),
      .m_status_overflow(),
      .m_status_bad_frame(),
      .m_status_good_frame()
  );

  // helper tasks -----------------------------------------------------------
  // Buffer to capture data transmitted on the QSFP1 TX stream so it can be
  // decoded when the frame boundary is reached.
  byte tx_frame[0:2047];
  int  tx_count = 0;

  task send_chunk(input [DATA_WIDTH-1:0] data,
                  input [KEEP_WIDTH-1:0] keep,
                  input last);
    begin
      rx_axis_tdata  <= data;
      rx_axis_tkeep  <= keep;
      rx_axis_tvalid <= 1;
      rx_axis_tlast  <= last;
      rx_axis_tuser  <= 0;
      @(posedge clk);
      rx_axis_tvalid <= 0;
      rx_axis_tlast  <= 0;
    end
  endtask

  // collect bytes from qsfp1_tx_axis and decode on frame boundaries
  always @(posedge clk) begin
    if (rst) begin
      tx_count <= 0;
    end else if (qsfp1_tx_axis_tvalid && qsfp1_tx_axis_tready) begin
      int i;
      for (i = 0; i < KEEP_WIDTH; i = i + 1) begin
        if (qsfp1_tx_axis_tkeep[i]) begin
          tx_frame[tx_count] <= qsfp1_tx_axis_tdata[i*8 +: 8];
          tx_count <= tx_count + 1;
        end
      end
      if (qsfp1_tx_axis_tlast) begin
        decode_packet(tx_count);
        tx_count <= 0;
      end
    end
  end

  task send_frame(input [DATA_WIDTH-1:0] d0,
                  input [KEEP_WIDTH-1:0] k0,
                  input [DATA_WIDTH-1:0] d1,
                  input [KEEP_WIDTH-1:0] k1);
    begin
      send_chunk(d0, k0, 0);
      send_chunk(d1, k1, 1);
    end
  endtask

  // convenient keep constants
  localparam [KEEP_WIDTH-1:0] KEEP_ALL  = {KEEP_WIDTH{1'b1}};
  localparam [KEEP_WIDTH-1:0] KEEP_LAST = {{(KEEP_WIDTH-42){1'b0}}, {42{1'b1}}};
  localparam [KEEP_WIDTH-1:0] KEEP_LAST_PING = {{(KEEP_WIDTH-10){1'b0}}, {10{1'b1}}};

  // alternating 0xaa55 pattern used for ICMP payload
  localparam [255:0] PING_PAYLOAD = 256'h55aa55aa55aa55aa55aa55aa55aa55aa55aa55aa55aa55aa55aa55aa55aa55aa;

  // connection manager parameters -----------------------------------------
  localparam [31:0] PC_IP    = 32'h1601d40b;           // 22.1.212.11
  localparam [31:0] FPGA_IP  = 32'h1601d40a;           // 22.1.212.10
  localparam [47:0] PC_MAC   = 48'hb8599fed814d;       // B8:59:9F:ED:81:4D
  localparam [23:0] LOCAL_QP = 24'd999;
  localparam [31:0] LOCAL_RKEY = 32'h00000219;
  localparam [63:0] LOCAL_VADDR = 64'h00007f24b8e8a000;
  localparam [23:0] REMOTE_QP = 24'd256;
  localparam [15:0] CM_DST_PORT = 16'h4321;
  localparam [15:0] CM_SRC_PORT = 16'h4322;

    // build connection manager header from address parameters
  // Build the connection manager header.  The result is stored little-endian so
  // that CM_HDR[7:0] is the first byte transmitted on AXI.  All multi-byte
  // parameters are supplied in normal network order (big-endian).
  function automatic [335:0] build_cm_hdr(
      input [47:0] dst_mac,
      input [47:0] src_mac,
      input [31:0] src_ip,
      input [31:0] dst_ip,
      input [15:0] src_port,
      input [15:0] dst_port
  );
      reg [7:0] b [0:41];
      reg [335:0] h;
      integer i;

      // destination MAC address
      for (i = 0; i < 6; i = i + 1) begin
          b[i] = dst_mac[47 - i*8 -: 8];
      end

      // source MAC address
      for (i = 0; i < 6; i = i + 1) begin
          b[i+6] = src_mac[47 - i*8 -: 8];
      end

      // EtherType
      b[12] = 8'h08;
      b[13] = 8'h00;

      // IPv4 header
      b[14] = 8'h45;              // version, IHL
      b[15] = 8'h00;              // DSCP/ECN
      {b[16], b[17]} = 16'h005c;  // total length
      {b[18], b[19]} = 16'h0000;  // identification
      {b[20], b[21]} = 16'h0000;  // flags/fragment offset
      b[22] = 8'h40;              // TTL
      b[23] = 8'h11;              // protocol: UDP
      {b[24], b[25]} = 16'h0000;  // header checksum (ignored)
      {b[26], b[27], b[28], b[29]} = src_ip;
      {b[30], b[31], b[32], b[33]} = dst_ip;

      // UDP header
      {b[34], b[35]} = src_port;
      {b[36], b[37]} = dst_port;
      {b[38], b[39]} = 16'h0048;   // length
      {b[40], b[41]} = 16'h0000;   // checksum

      // pack bytes into little-endian vector
      h = 0;
      for (i = 0; i < 42; i = i + 1) begin
          h[i*8 +: 8] = b[i];
      end

      build_cm_hdr = h;
  endfunction

  localparam [47:0] CM_DST_MAC = 48'h020000000000;
  // header stored little-endian so first AXI byte is the destination MAC MSB
  localparam [335:0] CM_HDR = build_cm_hdr(CM_DST_MAC, PC_MAC, PC_IP, FPGA_IP, CM_SRC_PORT, CM_DST_PORT);

  function automatic [511:0] build_cm_payload(
      input [2:0]  req_type,
      input [23:0] rem_qpn,
      input        txmeta_valid,
      input        txmeta_start,
      input [31:0] dma_len,
      input [31:0] n_transfers
  );
      build_cm_payload = 0;
      build_cm_payload[0]        = 1'b1;
      build_cm_payload[3:1]      = req_type;
      build_cm_payload[32:8]     = LOCAL_QP;
      build_cm_payload[63:40]    = 24'd0;
      build_cm_payload[103:72]   = LOCAL_RKEY;
      build_cm_payload[167:104]  = LOCAL_VADDR;
      build_cm_payload[199:168]  = PC_IP;
      build_cm_payload[223:200]  = rem_qpn;
      build_cm_payload[255:232]  = 24'd0;
      build_cm_payload[295:264]  = 32'd0;
      build_cm_payload[359:296]  = 64'd0;
      build_cm_payload[391:360]  = FPGA_IP;
      build_cm_payload[407:392]  = CM_SRC_PORT;
      build_cm_payload[408]      = txmeta_valid;
      build_cm_payload[409]      = txmeta_start;
      build_cm_payload[410]      = 1'b0;
      build_cm_payload[411]      = 1'b1;
      build_cm_payload[447:416]  = dma_len;
      build_cm_payload[479:448]  = n_transfers;
  endfunction

  function automatic [1023:0] assemble_frame(input [511:0] payload);
      reg [1023:0] f;
      f = 0;
      f[335:0]   = CM_HDR;
      f[511:336] = payload[175:0];
      f[847:512] = payload[511:176];
      assemble_frame = f;
  endfunction

  function automatic [15:0] calc_checksum(input int len, input byte data[]);
      int i;
      int sum;
      begin
          sum = 0;
          for (i = 0; i < len; i = i + 2) begin
              sum = sum + {data[i], data[i+1]};
          end
          sum = (sum >> 16) + (sum & 16'hffff);
          sum = (sum >> 16) + (sum & 16'hffff);
          calc_checksum = ~sum[15:0];
      end
  endfunction

  function automatic [1023:0] build_ping_frame(
      input [31:0] src_ip,
      input [31:0] dst_ip,
      input [15:0] id,
      input [15:0] seq
  );
      byte pkt[0:73];
      int i;
      reg [15:0] csum;
      reg [1023:0] f;

      // Ethernet header
      pkt[0] = 8'h02; pkt[1] = 8'h00; pkt[2] = 8'h00; pkt[3] = 8'h00; pkt[4] = 8'h00; pkt[5] = 8'h00; // dst
        pkt[6] = PC_MAC[47:40];
        pkt[7] = PC_MAC[39:32];
        pkt[8] = PC_MAC[31:24];
        pkt[9] = PC_MAC[23:16];
        pkt[10] = PC_MAC[15:8];
        pkt[11] = PC_MAC[7:0]; // src
      pkt[12] = 8'h08; pkt[13] = 8'h00; // eth type

      // IP header
      pkt[14] = 8'h45; // version/IHL
      pkt[15] = 8'h00;
      pkt[16] = 8'h00; pkt[17] = 8'h3c; // total length 60 bytes
      pkt[18] = id[15:8]; pkt[19] = id[7:0];
      pkt[20] = 8'h00; pkt[21] = 8'h00; // flags/frag
      pkt[22] = 8'h40; pkt[23] = 8'h01; // ttl, protocol
      pkt[24] = 8'h00; pkt[25] = 8'h00; // checksum placeholder
      pkt[26] = src_ip[31:24]; pkt[27] = src_ip[23:16];
      pkt[28] = src_ip[15:8];  pkt[29] = src_ip[7:0];
      pkt[30] = dst_ip[31:24]; pkt[31] = dst_ip[23:16];
      pkt[32] = dst_ip[15:8];  pkt[33] = dst_ip[7:0];

      // compute IP header checksum
      csum = calc_checksum(20, pkt[14+:20]);
      pkt[24] = csum[15:8];
      pkt[25] = csum[7:0];

      // ICMP header
      pkt[34] = 8'h08; pkt[35] = 8'h00; // type, code
      pkt[36] = 8'h00; pkt[37] = 8'h00; // checksum placeholder
      pkt[38] = id[15:8]; pkt[39] = id[7:0];
      pkt[40] = seq[15:8]; pkt[41] = seq[7:0];

      for (i = 0; i < 32; i = i + 1) begin
          pkt[42+i] = PING_PAYLOAD[i*8 +: 8];
      end

      // compute ICMP checksum
      csum = calc_checksum(40, pkt[34+:40]);
      pkt[36] = csum[15:8];
      pkt[37] = csum[7:0];

      f = 0;
      for (i = 0; i < 74; i = i + 1) begin
          f[i*8 +: 8] = pkt[i];
      end
      build_ping_frame = f;
  endfunction

  // build an ARP reply frame
  function automatic [511:0] build_arp_reply(
      input [47:0] sha,
      input [31:0] spa,
      input [47:0] tha,
      input [31:0] tpa
  );
      byte pkt[0:41];
      int i;
      reg [511:0] f;

      // Ethernet header
      pkt[0]  = tha[47:40];
      pkt[1]  = tha[39:32];
      pkt[2]  = tha[31:24];
      pkt[3]  = tha[23:16];
      pkt[4]  = tha[15:8];
      pkt[5]  = tha[7:0];
      pkt[6]  = sha[47:40];
      pkt[7]  = sha[39:32];
      pkt[8]  = sha[31:24];
      pkt[9]  = sha[23:16];
      pkt[10] = sha[15:8];
      pkt[11] = sha[7:0];
      pkt[12] = 8'h08;
      pkt[13] = 8'h06;

      // ARP payload
      pkt[14] = 8'h00; pkt[15] = 8'h01; // htype
      pkt[16] = 8'h08; pkt[17] = 8'h00; // ptype
      pkt[18] = 8'h06; // hlen
      pkt[19] = 8'h04; // plen
      pkt[20] = 8'h00; pkt[21] = 8'h02; // opcode reply

      pkt[22] = sha[47:40];
      pkt[23] = sha[39:32];
      pkt[24] = sha[31:24];
      pkt[25] = sha[23:16];
      pkt[26] = sha[15:8];
      pkt[27] = sha[7:0];

      pkt[28] = spa[31:24];
      pkt[29] = spa[23:16];
      pkt[30] = spa[15:8];
      pkt[31] = spa[7:0];

      pkt[32] = tha[47:40];
      pkt[33] = tha[39:32];
      pkt[34] = tha[31:24];
      pkt[35] = tha[23:16];
      pkt[36] = tha[15:8];
      pkt[37] = tha[7:0];

      pkt[38] = tpa[31:24];
      pkt[39] = tpa[23:16];
      pkt[40] = tpa[15:8];
      pkt[41] = tpa[7:0];

      f = 0;
      for (i = 0; i < 42; i = i + 1) begin
          f[i*8 +: 8] = pkt[i];
      end
      build_arp_reply = f;
  endfunction

  // --------------------------------------------------------------
  // Monitor the TX stream from the core and decode Ethernet frames
  // --------------------------------------------------------------

  task automatic decode_packet(input int len);
    int i;
    reg [15:0] eth_type;
    reg [7:0] ip_proto;
    begin
      $display("[%0t] ---- TX FRAME (%0d bytes) ----", $time, len);
      $display("[%0t]  DST %02x:%02x:%02x:%02x:%02x:%02x", $time,
               tx_frame[0], tx_frame[1], tx_frame[2],
               tx_frame[3], tx_frame[4], tx_frame[5]);
      $display("[%0t]  SRC %02x:%02x:%02x:%02x:%02x:%02x", $time,
               tx_frame[6], tx_frame[7], tx_frame[8],
               tx_frame[9], tx_frame[10], tx_frame[11]);
      eth_type = {tx_frame[12], tx_frame[13]};
      $display("[%0t]  ETH TYPE 0x%04x", $time, eth_type);

      if (eth_type == 16'h0800 && len >= 34) begin
        ip_proto = tx_frame[23];
        $display("[%0t]   IP SRC %0d.%0d.%0d.%0d", $time,
                 tx_frame[26], tx_frame[27], tx_frame[28], tx_frame[29]);
        $display("[%0t]   IP DST %0d.%0d.%0d.%0d", $time,
                 tx_frame[30], tx_frame[31], tx_frame[32], tx_frame[33]);
        $display("[%0t]   IP PROTO %0d", $time, ip_proto);
        if (ip_proto == 17 && len >= 42) begin
          $display("[%0t]    UDP SPORT %0d DPORT %0d", $time,
                   {tx_frame[34], tx_frame[35]}, {tx_frame[36], tx_frame[37]});
        end else if (ip_proto == 1 && len >= 42) begin
          $display("[%0t]    ICMP TYPE %0d CODE %0d", $time,
                   tx_frame[34], tx_frame[35]);
        end
      end
    end
  endtask

  // simple monitor to display transmitted frames
  always @(posedge clk) begin
    if (fifo_tx_axis_tvalid) begin
      $display("[%0t] TX %h keep=%h last=%b", $time,
               fifo_tx_axis_tdata, fifo_tx_axis_tkeep, fifo_tx_axis_tlast);
    end
  end

  task monitor_ping_reply();
    reg [DATA_WIDTH-1:0] d0, d1;
    reg [KEEP_WIDTH-1:0] k0, k1;
    begin
      @(posedge clk);
      wait(fifo_tx_axis_tvalid);
      d0 = fifo_tx_axis_tdata;
      k0 = fifo_tx_axis_tkeep;
      if (!fifo_tx_axis_tlast) begin
        @(posedge clk);
        d1 = fifo_tx_axis_tdata;
        k1 = fifo_tx_axis_tkeep;
      end else begin
        d1 = 0;
        k1 = 0;
      end
      $display("[%0t] RX PING REPLY %h %h", $time, d0, d1);
    end
  endtask

  reg [DATA_WIDTH-1:0] OPEN_CH0, OPEN_CH1;
  reg [DATA_WIDTH-1:0] MOD_CH0, MOD_CH1;
  reg [DATA_WIDTH-1:0] START_CH0, START_CH1;
  reg [DATA_WIDTH-1:0] CLOSE_CH0, CLOSE_CH1;
  reg [DATA_WIDTH-1:0] PING_CH0, PING_CH1;
  reg [DATA_WIDTH-1:0] ARP_CH0;

  initial begin
    reg [1023:0] frame;
    wait(!rst);
    @(posedge clk);

    // send initial ping request and wait for reply
    frame = build_ping_frame(PC_IP, FPGA_IP, 16'd1, 16'd1);
    {PING_CH1, PING_CH0} = frame;
    send_frame(PING_CH0, KEEP_ALL, PING_CH1, KEEP_LAST_PING);
    monitor_ping_reply();
    repeat(20) @(posedge clk);

    // preload ARP cache on the DUT
    frame = build_arp_reply(PC_MAC, PC_IP, 48'h020000000000, FPGA_IP);
    ARP_CH0 = frame;
    send_chunk(ARP_CH0, KEEP_LAST, 1);
    @(posedge fifo_tx_axis_tvalid);
    repeat(20) @(posedge clk);

    // 1) open connection
    frame = assemble_frame(build_cm_payload(3'd1, REMOTE_QP, 1'b0, 1'b0, 32'd0, 32'd0));
    {OPEN_CH1, OPEN_CH0} = frame;
    send_frame(OPEN_CH0, KEEP_ALL, OPEN_CH1, KEEP_LAST);
    $display("[%0t] OPEN QP", $time);
    @(posedge fifo_tx_axis_tvalid);
    repeat(40) @(posedge clk);

    // 2) modify QP to RTS
    frame = assemble_frame(build_cm_payload(3'd3, REMOTE_QP, 1'b0, 1'b0, 32'd0, 32'd0));
    {MOD_CH1, MOD_CH0} = frame;
    send_frame(MOD_CH0, KEEP_ALL, MOD_CH1, KEEP_LAST);
    $display("[%0t] Change QP to RTS", $time);
    @(posedge fifo_tx_axis_tvalid);
    repeat(40) @(posedge clk);

    // 3) start dummy transfer
    frame = assemble_frame(build_cm_payload(3'd0, REMOTE_QP, 1'b1, 1'b1, 32'd40960, 32'd1));
    {START_CH1, START_CH0} = frame;
    send_frame(START_CH0, KEEP_ALL, START_CH1, KEEP_LAST);
    $display("[%0t] Start transfer", $time);
    @(posedge fifo_tx_axis_tvalid);
    repeat(800) @(posedge clk);

    // send initial ping request and wait for reply
    frame = build_ping_frame(PC_IP, FPGA_IP, 16'd1, 16'd1);
    {PING_CH1, PING_CH0} = frame;
    send_frame(PING_CH0, KEEP_ALL, PING_CH1, KEEP_LAST_PING);
    monitor_ping_reply();
    repeat(20) @(posedge clk);

//    // 4) close connection
//    frame = assemble_frame(build_cm_payload(3'd4, REMOTE_QP, 1'b0, 1'b0, 32'd0, 32'd0));
//    {CLOSE_CH1, CLOSE_CH0} = frame;
//    send_frame(CLOSE_CH0, KEEP_ALL, CLOSE_CH1, KEEP_LAST);
//    repeat(20) @(posedge clk);

    $finish;
  end

endmodule

`resetall
