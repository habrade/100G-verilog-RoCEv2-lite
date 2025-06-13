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

  // connection manager parameters -----------------------------------------
  localparam [31:0] PC_IP    = 32'h1601d40b;           // 22.1.212.11
  localparam [31:0] FPGA_IP  = 32'h1601d40a;           // 22.1.212.10
  localparam [23:0] LOCAL_QP = 24'd17;
  localparam [31:0] LOCAL_RKEY = 32'h00000219;
  localparam [63:0] LOCAL_VADDR = 64'h00007f24b8e8a000;
  localparam [23:0] REMOTE_QP = 24'd256;
  localparam [15:0] CM_DST_PORT = 16'h4321;
  localparam [15:0] CM_SRC_PORT = 16'h4322;

  // Ethernet/IP/UDP header with destination MAC 02:00:00:00:00:00
  // Stored little-endian so the first AXI byte is the destination MAC MSB
  localparam [335:0] CM_HDR = 336'h00004800214322430ad401160bd4011600001140000000005c0000450008120000341234000000000002;

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

  // simple monitor to display transmitted frames
  always @(posedge clk) begin
    if (fifo_tx_axis_tvalid) begin
      $display("TX %h keep=%h last=%b", fifo_tx_axis_tdata, fifo_tx_axis_tkeep, fifo_tx_axis_tlast);
    end
  end

  reg [DATA_WIDTH-1:0] OPEN_CH0, OPEN_CH1;
  reg [DATA_WIDTH-1:0] MOD_CH0, MOD_CH1;
  reg [DATA_WIDTH-1:0] START_CH0, START_CH1;
  reg [DATA_WIDTH-1:0] CLOSE_CH0, CLOSE_CH1;

  initial begin
    reg [1023:0] frame;
    wait(!rst);
    @(posedge clk);

    // 1) open connection
    frame = assemble_frame(build_cm_payload(3'd1, 24'd0, 1'b0, 1'b0, 32'd0, 32'd0));
    {OPEN_CH1, OPEN_CH0} = frame;
    send_frame(OPEN_CH0, KEEP_ALL, OPEN_CH1, KEEP_LAST);
    repeat(20) @(posedge clk);

    // 2) modify QP to RTS
    frame = assemble_frame(build_cm_payload(3'd3, REMOTE_QP, 1'b0, 1'b0, 32'd0, 32'd0));
    {MOD_CH1, MOD_CH0} = frame;
    send_frame(MOD_CH0, KEEP_ALL, MOD_CH1, KEEP_LAST);
    repeat(20) @(posedge clk);

    // 3) start dummy transfer
    frame = assemble_frame(build_cm_payload(3'd0, REMOTE_QP, 1'b1, 1'b1, 32'd16000, 32'd100));
    {START_CH1, START_CH0} = frame;
    send_frame(START_CH0, KEEP_ALL, START_CH1, KEEP_LAST);
    repeat(20) @(posedge clk);

    // 4) close connection
    frame = assemble_frame(build_cm_payload(3'd4, REMOTE_QP, 1'b0, 1'b0, 32'd0, 32'd0));
    {CLOSE_CH1, CLOSE_CH0} = frame;
    send_frame(CLOSE_CH0, KEEP_ALL, CLOSE_CH1, KEEP_LAST);
    repeat(20) @(posedge clk);

    $finish;
  end

endmodule

`resetall
