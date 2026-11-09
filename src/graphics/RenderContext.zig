const zalg = @import("zalgebra");
const Light = @import("light.zig").Light;

const RenderContext = @This();

pub const diffuse_unit = 0;
pub const shadow_map_unit = 1;

pub const Lighting = struct {
    light: *const Light,
    shadow_view_projection: ?zalg.Mat4 = null,
};

view: zalg.Mat4,
projection: zalg.Mat4,
lighting: ?Lighting = null,
