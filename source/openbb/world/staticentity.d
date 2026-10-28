module openbb.world.staticentity;
import openbb.world.entity;
import openbb.world.geometry;
class StaticEntity : Entity {
    this(uint id, Position position, Size footprint) { super(id,position,footprint); }
}
