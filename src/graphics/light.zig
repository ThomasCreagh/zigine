const PointLight = @import("lights/PointLight.zig");

pub const Light = union(enum) { pointlight: PointLight };
