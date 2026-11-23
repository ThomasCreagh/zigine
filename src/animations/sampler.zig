const zalg = @import("zalgebra");

const gltf_loader = @import("../graphics/gltf_loader.zig");
const Skeleton = @import("Skeleton.zig");

const Clip = gltf_loader.Clip;
const Track = gltf_loader.Track;

// time falls between two keyframes
const Key = struct {
    previous: usize,
    next: usize,
    // 0 at previous 1 at next
    t: f32,
    // secs between previous and next
    delta: f32,
};

pub fn sample(clip: *const Clip, time: f32, skeleton: *Skeleton) void {
    for (clip.tracks) |*track| {
        switch (track.path) {
            .translation => skeleton.translations[track.node] = sampleVec3(track, time),
            .rotation => skeleton.rotations[track.node] = sampleQuat(track, time),
            .scale => skeleton.scales[track.node] = sampleVec3(track, time),
            .weights => {},
        }
    }
}

fn sampleVec3(track: *const Track, time: f32) zalg.Vec3 {
    const value = sampleComponents(3, track, findKey(track.times, time));
    return zalg.Vec3.new(value[0], value[1], value[2]);
}

fn sampleQuat(track: *const Track, time: f32) zalg.Quat {
    const key = findKey(track.times, time);

    if (track.interpolation == .LINEAR) {
        const previous = zalg.Quat.fromSlice(keyValue(4, track, key.previous));
        const next = zalg.Quat.fromSlice(keyValue(4, track, key.next));
        return previous.slerp(next, key.t).norm();
    }

    return zalg.Quat.fromSlice(&sampleComponents(4, track, key)).norm();
}

fn sampleComponents(comptime n: usize, track: *const Track, key: Key) [n]f32 {
    const previous = keyValue(n, track, key.previous);
    const next = keyValue(n, track, key.next);

    var result: [n]f32 = undefined;

    switch (track.interpolation) {
        .STEP => result = previous.*,
        .LINEAR => for (&result, previous, next) |*component, a, b| {
            component.* = a + (b - a) * key.t;
        },
        .CUBICSPLINE => {
            const out_tangent = tangent(n, track, key.previous, 2);
            const in_tangent = tangent(n, track, key.next, 0);

            const t = key.t;
            const t2 = t * t;
            const t3 = t2 * t;

            for (&result, 0..) |*component, i| {
                component.* = (2 * t3 - 3 * t2 + 1) * previous[i] +
                    key.delta * (t3 - 2 * t2 + t) * out_tangent[i] +
                    (-2 * t3 + 3 * t2) * next[i] +
                    key.delta * (t3 - t2) * in_tangent[i];
            }
        },
    }

    return result;
}

fn keyValue(comptime n: usize, track: *const Track, key: usize) *const [n]f32 {
    const element = if (track.interpolation == .CUBICSPLINE) key * 3 + 1 else key;
    return track.values[element * n ..][0..n];
}

fn tangent(comptime n: usize, track: *const Track, key: usize, slot: usize) *const [n]f32 {
    return track.values[(key * 3 + slot) * n ..][0..n];
}

// before the first or after the last key
fn findKey(times: []const f32, time: f32) Key {
    const last = times.len - 1;

    if (time <= times[0]) return .{ .previous = 0, .next = 0, .t = 0, .delta = 0 };
    if (time >= times[last]) return .{ .previous = last, .next = last, .t = 0, .delta = 0 };

    // binsearch
    var low: usize = 0;
    var high: usize = last;
    while (high - low > 1) {
        const middle = (low + high) / 2;
        if (times[middle] <= time) low = middle else high = middle;
    }

    const delta = times[high] - times[low];

    return .{
        .previous = low,
        .next = high,
        .t = (time - times[low]) / delta,
        .delta = delta,
    };
}
