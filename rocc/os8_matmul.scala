package freechips.rocketchip.tile

import chisel3._
import org.chipsalliance.cde.config.Parameters
import freechips.rocketchip.rocket.constants.MemoryOpConstants

class os8_matmul(opcodes: OpcodeSet)(implicit p: Parameters)
  extends LazyRoCC(opcodes) {
  override lazy val module = new os8_matmulModule(this)
}

class os8_matmulModule(outer: os8_matmul)(implicit p: Parameters)
  extends LazyRoCCModuleImp(outer)
  with MemoryOpConstants {

  val xLenBits = io.cmd.bits.rs1.getWidth
  val bb = Module(new os8_wrapper(xLenBits))

  bb.io.clk   := clock
  bb.io.rst_n := !reset.asBool

  bb.io.cmd_valid := io.cmd.valid
  io.cmd.ready    := bb.io.cmd_ready
  bb.io.cmd_funct := io.cmd.bits.inst.funct
  bb.io.cmd_rs1   := io.cmd.bits.rs1
  bb.io.cmd_rd    := io.cmd.bits.inst.rd

  io.resp.valid     := bb.io.resp_valid
  bb.io.resp_ready  := io.resp.ready
  io.resp.bits.rd   := bb.io.resp_rd
  io.resp.bits.data := bb.io.resp_data

  io.mem.req.valid     := bb.io.mem_req_valid
  bb.io.mem_req_ready  := io.mem.req.ready
  io.mem.req.bits.addr := bb.io.mem_req_addr
  io.mem.req.bits.tag  := bb.io.mem_req_tag
  io.mem.req.bits.cmd  := bb.io.mem_req_cmd
  io.mem.req.bits.size := bb.io.mem_req_size
  io.mem.req.bits.data := bb.io.mem_req_data

  io.mem.req.bits.phys     := false.B
  io.mem.req.bits.signed   := false.B
  io.mem.req.bits.no_alloc := false.B
  io.mem.req.bits.no_xcpt  := false.B
  io.mem.req.bits.dv       := io.cmd.bits.status.dv
  io.mem.req.bits.dprv     := io.cmd.bits.status.dprv

  io.mem.s1_kill := false.B
  io.mem.s2_kill := false.B
  io.mem.keep_clock_enabled := true.B

  bb.io.mem_resp_valid := io.mem.resp.valid
  bb.io.mem_resp_tag   := io.mem.resp.bits.tag
  bb.io.mem_resp_data  := io.mem.resp.bits.data

  io.busy := bb.io.busy
  io.interrupt := false.B
}


  
