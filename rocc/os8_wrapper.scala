package freechips.rocketchip.tile

import chisel3._
import chisel3.util.HasBlackBoxResource

class os8_wrapper(val xLen: Int)
  extends BlackBox(Map("XLEN" -> xLen))
  with HasBlackBoxResource {

  val io = IO(new Bundle {
    val clk   = Input(Clock())
    val rst_n = Input(Bool())

    val cmd_valid = Input(Bool())
    val cmd_ready = Output(Bool())
    val cmd_funct = Input(UInt(7.W))
    val cmd_rs1   = Input(UInt(xLen.W))
    val cmd_rd    = Input(UInt(5.W))

    val resp_valid = Output(Bool())
    val resp_ready = Input(Bool())
    val resp_rd    = Output(UInt(5.W))
    val resp_data  = Output(UInt(xLen.W))

    val mem_req_valid = Output(Bool())
    val mem_req_ready = Input(Bool())
    val mem_req_addr  = Output(UInt(xLen.W))
    val mem_req_tag   = Output(UInt(8.W))
    val mem_req_cmd   = Output(UInt(5.W))
    val mem_req_size  = Output(UInt(3.W))
    val mem_req_data  = Output(UInt(xLen.W))

    val mem_resp_valid = Input(Bool())
    val mem_resp_tag   = Input(UInt(8.W))
    val mem_resp_data  = Input(UInt(xLen.W))

    val busy = Output(Bool())
  })

addResource("/vsrc/os8_wrapper.sv")
addResource("/vsrc/os8_delay_mem.sv")
addResource("/vsrc/os8_pe_mesh.sv")
addResource("/vsrc/os8_rocc_cmd_regs.sv")
addResource("/vsrc/os8_controller.sv")
addResource("/vsrc/os8_activation_unit.sv")
addResource("/vsrc/os8_final_cpa.sv")
addResource("/vsrc/os8_sa.sv")
addResource("/vsrc/os8_pe.sv")
}





