// Append this to the existing Configs.scala in
// generators/rocket-chip/src/main/scala/subsystem/
//
// Defines the RoCC attachment mixin used by OS8RocketConfig. The accelerator is
// attached through the Rocket Chip BuildRoCC mechanism on the custom0 opcode space.

class WithOS8RoCC extends Config((site, here, up) => {
  case BuildRoCC => Seq((p: Parameters) => {
    val rocc = LazyModule(new os8_matmul(OpcodeSet.custom0)(p))
    rocc
  })
})
