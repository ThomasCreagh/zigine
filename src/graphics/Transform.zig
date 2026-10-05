const zalg = @import("zalgebra");

const Transform = @This();

position: zalg.Vec3 = zalg.Vec3.new(0, 0, 0),
/// rotation in radians
rotation: zalg.Vec3 = zalg.Vec3.new(0, 0, 0),
scale: zalg.Vec3 = zalg.Vec3.new(1, 1, 1),

pub fn matrix(self: *const Transform) zalg.Mat4 {
    const translation = zalg.Mat4.fromTranslate(self.position);

    const rotation_x = zalg.Mat4.fromRotation(
        self.rotation.data[0],
        zalg.Vec3.new(1, 0, 0),
    );

    const rotation_y = zalg.Mat4.fromRotation(
        self.rotation.data[1],
        zalg.Vec3.new(0, 1, 0),
    );

    const rotation_z = zalg.Mat4.fromRotation(
        self.rotation.data[2],
        zalg.Vec3.new(0, 0, 1),
    );

    const scaling = zalg.Mat4.fromScale(self.scale);

    return translation
        .mul(rotation_z)
        .mul(rotation_y)
        .mul(rotation_x)
        .mul(scaling);
}
