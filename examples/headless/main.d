/// Executable architecture example, not a reconstruction of native worker AI.
module headless_demo;
import openbb.world.map;
import openbb.world.dynamicentity;
import openbb.world.geometry;
import openbb.graphics.scene;
import std.stdio : writeln;
import std.json;

void main() {
    auto world = new Map(3,2);
    auto worker = new DynamicEntity(1,Position(0,0));
    worker.resource = "example-worker.mfb"; // identifier only; no assets are loaded
    worker.animation.play(0,8,100);
    worker.inventory.add("example-wheat",3);
    worker.assignJob("example-delivery",2);
    worker.walk(Position(3,4),1);
    world.addEntity(worker);
    foreach (step; 0..100) world.tick();
    auto snapshot = world.snapshot();
    auto scene = buildScene(snapshot,"example-tiles.mfb");
    JSONValue result = JSONValue.emptyObject;
    result["model"] = "prototype; no native AI or production rules";
    result["ticks"] = world.ticks;
    result["tick_ms"] = world.tickMilliseconds;
    result["position"] = JSONValue([worker.position.x,worker.position.y]);
    result["animation_frame"] = worker.animation.frame;
    result["inventory"] = worker.inventory.quantity("example-wheat");
    result["draw_commands"] = scene.length;
    writeln(result.toPrettyString());
}
