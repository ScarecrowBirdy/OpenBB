module openbb.world.layer;
import openbb.world.tile;
import std.exception : enforce;
struct LayerSnapshot { Tile[] tiles; }
/// Explicit ordered tile plane; not a native terrain/road/visibility record.
final class Layer {
private:
    Tile[] _tiles;
public:
    this(size_t cells) { _tiles.length = cells; }
    Tile opIndex(size_t index) const {
        enforce(index < _tiles.length, "Tile index out of range"); return _tiles[index];
    }
    void opIndexAssign(Tile tile, size_t index) {
        enforce(index < _tiles.length, "Tile index out of range"); _tiles[index] = tile;
    }
    LayerSnapshot snapshot() const { return LayerSnapshot(_tiles.dup); }
}
