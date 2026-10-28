module world_tests;
import openbb.world.geometry;
import openbb.world.animation;
import openbb.world.entity;
import openbb.world.dynamicentity;
import openbb.world.staticentity;
import openbb.world.building;
import openbb.world.inventory;
import openbb.world.map;
import openbb.world.tile;
import openbb.graphics.scene;
import std.exception : assertThrown;
import std.math : isClose;

unittest {
    Animation a;
    assert(a.frame == 0 && !a.playing);
    a.tick(1000); assert(a.frame == 0);
    a.play(2,5,100);
    a.tick(99); assert(a.frame == 2);
    a.tick(1); assert(a.frame == 3);
    a.stop(); a.tick(10000); assert(a.frame == 3);
    a.resume(); a.tick(200); assert(a.frame == 2);
    a.seek(4); a.tick(100); assert(a.frame == 2);
    assertThrown!Exception(a.play(1,1));
    assertThrown!Exception(a.play(0,2,0));
    assertThrown!Exception(a.seek(5));
    Animation b; a.play(3,13,7); b.play(3,13,7);
    a.tick(uint.max); b.tick(uint.max-100); b.tick(100);
    assert(a.frame == b.frame);
}

unittest {
    auto actor = new DynamicEntity(7,Position(0,0));
    actor.layer = 2; assert(actor.layer == 2); // old getter recursively called itself
    actor.walk(Position(3,4),5);
    actor.tick(500);
    assert(isClose(actor.position.x,1.5) && isClose(actor.position.y,2));
    assert(actor.state == State.Walking);
    actor.tick(5000);
    assert(actor.position == Position(3,4) && actor.state == State.Idle);
    actor.walk(actor.position,1); assert(actor.state == State.Idle);
    actor.walk(Position(0,0),5); actor.stop(); actor.tick(1000);
    assert(actor.position == Position(3,4));
    assertThrown!Exception(actor.walk(Position(0,0),0));
    assertThrown!Exception(actor.position = Position(double.nan,0));
    auto building = new Building(8,Position(1,2),Size(2,3));
    building.prepareTopOut(); assert(building.stage == ConstructionStage.toppingOut);
    building.buildFinished(); assert(building.stage == ConstructionStage.complete);
    assert(building.snapshot().size == Size(2,3));
}

unittest {
    auto worker = new DynamicEntity(1);
    auto store = new Building(2,Position(10,0),Size(1,1));
    worker.assignJob("test-delivery",store.id);
    assert(worker.job.phase == JobPhase.assigned);
    worker.startJob(); worker.inventory.add("wheat",5);
    worker.inventory.transferTo(store.inventory,"wheat",3);
    assert(worker.inventory.quantity("wheat") == 2 && store.inventory.quantity("wheat") == 3);
    assert(worker.job.phase == JobPhase.working && worker.job.targetId == store.id);
    assertThrown!Exception(worker.inventory.transferTo(store.inventory,"wheat",3));
    assert(worker.inventory.quantity("wheat") == 2 && store.inventory.quantity("wheat") == 3);
    store.inventory.add("wheat",uint.max-3);
    assertThrown!Exception(worker.inventory.transferTo(store.inventory,"wheat",1));
    assert(worker.inventory.quantity("wheat") == 2 && store.inventory.quantity("wheat") == uint.max);
    worker.inventory.transferTo(worker.inventory,"wheat",2);
    assert(worker.inventory.quantity("wheat") == 2);
    worker.clearJob(); assert(worker.job.phase == JobPhase.idle);
    assertThrown!Exception(worker.startJob());
    assertThrown!Exception(worker.assignJob("",2));
}

unittest {
    auto world = new Map(3,2,100);
    assert(world.tile(2,1) == Tile.init);
    world.setTile(2,1,Tile(17,TileFlags.Fertile));
    auto overlay = world.addLayer(); world.setTile(1,0,Tile(3,0),overlay);
    auto actor = new DynamicEntity(1); actor.resource = "test.mfb";
    actor.animation.play(0,4,100); actor.walk(Position(10,0),1);
    actor.inventory.add("wheat",4); actor.assignJob("delivery",99);
    world.addEntity(actor);
    assertThrown!Exception(world.addEntity(new Entity(1)));
    assertThrown!Exception(world.tile(3,0));
    assertThrown!Exception(world.tile(0,2));
    assertThrown!Exception(world.setTile(0,0,Tile.init,2));
    auto before = world.snapshot();
    auto scene = buildScene(before,"tiles.mfb");
    assert(scene.length == 13 && scene[5].frame == 17);
    assert(scene[3].position == Position(39,20));
    foreach (i; 0..100) assert(buildScene(world.snapshot(),"tiles.mfb") == scene);
    assert(world.ticks == 0 && actor.position == Position(0,0) && actor.animation.frame == 0);
    world.tick(); assert(world.ticks == 1 && actor.animation.frame == 1);
    assert(isClose(actor.position.x,0.1));
    assert(before.entities[0].position == Position(0,0));
    // Snapshot ownership: edits to snapshots cannot mutate the model or another snapshot.
    before.layers[0].tiles[5].resID = 99;
    before.entities[0].inventory[0].quantity = 999;
    before.entities[0].job.name = "changed";
    assert(world.tile(2,1).resID == 17 && actor.inventory.quantity("wheat") == 4);
    assert(actor.job.name == "delivery");
    assertThrown!Exception(new Map(0,1));
    assertThrown!Exception(new Map(uint.max,uint.max));
    assertThrown!Exception(new Map(1,1,0));
}

unittest {
    // Render cadence cannot affect tick-driven movement/animation/state.
    auto a = new Map(1,1), b = new Map(1,1);
    auto aa = new DynamicEntity(1), bb = new DynamicEntity(1);
    aa.walk(Position(3,4),1); bb.walk(Position(3,4),1);
    aa.animation.play(0,8,75); bb.animation.play(0,8,75);
    a.addEntity(aa); b.addEntity(bb);
    foreach (i; 0..200) {
        a.tick(); b.tick();
        foreach (draw; 0..i%5) buildScene(a.snapshot(),"tiles.mfb");
    }
    assert(aa.snapshot() == bb.snapshot() && a.ticks == b.ticks);
}
void main() {}
