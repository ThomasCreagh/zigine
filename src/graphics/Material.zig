const zalg = @import("zalgebra");
const Texture = @import("opengl/Texture.zig");

diffuse_colour: zalg.Vec3 = zalg.Vec3.new(1, 1, 1),
diffuse_texture: ?*const Texture = null,
