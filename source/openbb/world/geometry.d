module openbb.world.geometry;
import std.math : isFinite;
import std.exception : enforce;

struct Position {
    double x = 0, y = 0;
    void validate() const { enforce(isFinite(x) && isFinite(y), "Non-finite position"); }
}
struct Size { uint width, height; }
