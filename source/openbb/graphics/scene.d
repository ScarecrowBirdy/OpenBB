/// Renderer-neutral commands. Building a scene never advances simulation.
module openbb.graphics.scene;
import openbb.world.map;
import openbb.world.geometry;
import std.exception : enforce;
import std.math : isFinite;

struct TileLayout {
    // Static terrain-loop evidence: horizontal 78, row advance 20, odd offset 39.
    // Not the sprite bounds or a complete native world-to-screen transformation.
    double columnStep = 78, rowStep = 20, oddRowOffset = 39;
    Position project(uint x, uint y) const {
        return Position(x*columnStep + (y%2 ? oddRowOffset : 0), y*rowStep);
    }
}
struct DrawCommand {
    string resource;
    uint frame;
    Position position;
    uint layer, entityId;
}
DrawCommand[] buildScene(const WorldSnapshot world, string tileResource, TileLayout layout = TileLayout()) {
    enforce(world.width > 0 && world.height > 0 && tileResource.length > 0, "Invalid scene input");
    enforce(isFinite(layout.columnStep) && isFinite(layout.rowStep) && isFinite(layout.oddRowOffset)
        && layout.columnStep > 0 && layout.rowStep > 0, "Invalid tile layout");
    DrawCommand[] commands;
    foreach (i, layer; world.layers) {
        enforce(layer.tiles.length == cast(ulong)world.width*world.height, "Incomplete scene layer");
        foreach (y; 0..world.height) foreach (x; 0..world.width) {
            auto tile = layer.tiles[cast(size_t)y*world.width+x];
            commands ~= DrawCommand(tileResource,tile.resID,layout.project(x,y),cast(uint)i,0);
        }
    }
    // Stable prototype order: tile planes, then actors in insertion order.
    // Native fixed-point depth sorting and composite overlays are future work.
    foreach (entity; world.entities)
        if (entity.resource.length)
            commands ~= DrawCommand(entity.resource,entity.frame,entity.position,entity.layer,entity.id);
    return commands;
}
