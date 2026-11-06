const zalg = @import("zalgebra");
const PointLight = @import("lights/PointLight.zig");

pub const Light = union(enum) {
    pointlight: PointLight,

    pub fn setPosition(self: *Light, position: zalg.Vec3) void {
        switch (self.*) {
            inline else => |*light| light.setPosition(position),
        }
    }

    pub fn viewMatrix(self: *const Light) zalg.Mat4 {
        return switch (self.*) {
            inline else => |light| light.viewMatrix(),
        };
    }

    pub fn projectionMatrix(self: *const Light) zalg.Mat4 {
        return switch (self.*) {
            inline else => |light| light.projectionMatrix(),
        };
    }

    pub fn viewProjectionMatrix(self: *const Light) zalg.Mat4 {
        return zalg.Mat4.mul(
            self.projectionMatrix(),
            self.viewMatrix(),
        );
    }
};
