// add this to the RocketConfigs.scala

class OS8RocketConfig extends Config(
  new freechips.rocketchip.subsystem.WithOS8RoCC ++
  new freechips.rocketchip.subsystem.WithNBigCores(1) ++
  new freechips.rocketchip.subsystem.WithoutTLMonitors ++
  new chipyard.config.AbstractConfig
)




