/// Bounded little-endian reads, independent of host alignment and byte order.
module openbb.io.binary;
import std.exception : enforce;

package(openbb) uint readLE(const(ubyte)[] data, size_t offset, size_t width)
{
    enforce(width > 0 && width <= 4 && offset <= data.length &&
        width <= data.length-offset, "Truncated binary field");
    uint value;
    foreach (i; 0..width) value |= cast(uint)data[offset+i] << (8*i);
    return value;
}
