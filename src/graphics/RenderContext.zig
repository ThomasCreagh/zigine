const zalg = @import("zalgebra");
const Light = @import("light.zig").Light;

const RenderContext = @This();

view: zalg.Mat4,
projection: zalg.Mat4,
light: *const Light,
