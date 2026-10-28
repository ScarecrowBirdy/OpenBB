module openbb.world.tile;
/// Prototype flags; these values are NOT the native 12-byte tile record flags.
enum TileFlags : ushort { Blocked = 1, Buildable = 2, Fertile = 4 }
struct Tile { ushort resID; ushort flags; }
