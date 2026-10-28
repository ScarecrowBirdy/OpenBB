module openbb.world.map;
import openbb.world.entity;
import openbb.world.layer;
import openbb.world.tile;
import std.exception : enforce;

struct WorldSnapshot {
    uint width, height;
    ulong ticks;
    LayerSnapshot[] layers;
    EntitySnapshot[] entities;
}
/// Headless prototype world. Stable insertion order, explicit fixed-duration ticks.
final class Map {
private:
    uint _width, _height, _tickMilliseconds;
    ulong _ticks;
    Layer[] _layers;
    Entity[] _entities;
    bool _ticking;
public:
    this(uint width, uint height, uint tickMilliseconds = 28) {
        enforce(width > 0 && height > 0 && cast(ulong)width*height <= 16*1024*1024,
            "Invalid/excessive map dimensions");
        enforce(tickMilliseconds > 0, "Tick duration must be positive");
        _width = width; _height = height; _tickMilliseconds = tickMilliseconds;
        addLayer();
    }
    uint addLayer() {
        enforce(_layers.length < 256, "Too many prototype map layers");
        _layers ~= new Layer(cast(size_t)_width*_height);
        return cast(uint)_layers.length-1;
    }
    private size_t cell(uint x, uint y, uint layer) const {
        enforce(x < _width && y < _height && layer < _layers.length, "Map coordinate/layer out of range");
        return cast(size_t)y*_width+x;
    }
    Tile tile(uint x, uint y, uint layer = 0) const { auto index = cell(x,y,layer); return _layers[layer][index]; }
    void setTile(uint x, uint y, Tile value, uint layer = 0) { auto index = cell(x,y,layer); _layers[layer][index] = value; }
    void addEntity(Entity entity) {
        enforce(!_ticking, "Cannot add entities during a world tick");
        enforce(entity !is null, "Null entity");
        foreach (existing; _entities) enforce(existing.id != entity.id, "Duplicate entity ID");
        _entities ~= entity;
    }
    // No wall clock, random tile generation, texture loading or draw calls here.
    void tick() {
        enforce(!_ticking, "Recursive world tick");
        enforce(_ticks < ulong.max, "World tick counter overflow");
        _ticking = true;
        scope(exit) _ticking = false;
        foreach (entity; _entities) entity.tick(_tickMilliseconds);
        ++_ticks;
    }
    WorldSnapshot snapshot() const {
        WorldSnapshot result;
        result.width = _width; result.height = _height; result.ticks = _ticks;
        foreach (layer; _layers) result.layers ~= layer.snapshot();
        foreach (entity; _entities) result.entities ~= entity.snapshot();
        return result;
    }
    @property uint width() const { return _width; }
    @property uint height() const { return _height; }
    @property uint tickMilliseconds() const { return _tickMilliseconds; }
    @property ulong ticks() const { return _ticks; }
}
