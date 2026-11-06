const zalg = @import("zalgebra");

const PointLight = @This();

const look_direction = zalg.Vec3.new(0, -1, 0);
const up = zalg.Vec3.new(0, 0, 1);

position: zalg.Vec3 = zalg.Vec3.new(0, 0, 0),
intensity: zalg.Vec3,

fov: f32 = 120.0,
near_plane: f32 = 50.0,
far_plane: f32 = 600.0,

pub fn viewMatrix(self: *const PointLight) zalg.Mat4 {
    const eye = self.position;
    const target = eye.add(look_direction);

    return zalg.Mat4.lookAt(
        eye,
        target,
        up,
    );
}

pub fn projectionMatrix(self: *const PointLight) zalg.Mat4 {
    return zalg.Mat4.perspective(
        self.fov,
        1.0,
        self.near_plane,
        self.far_plane,
    );
}
