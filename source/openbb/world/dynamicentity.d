/// Straight-line prototype movement, not the game's pathfinder/fixed-point rules.
module openbb.world.dynamicentity;
import openbb.world.entity;
import openbb.world.geometry;
import std.exception : enforce;
import std.math : hypot, isFinite;

class DynamicEntity : Entity {
private:
    Position _target;
    double _speed;
public:
    this(uint id, Position position = Position()) { super(id,position); }
    void walk(Position target, double unitsPerSecond) {
        target.validate();
        enforce(isFinite(unitsPerSecond) && unitsPerSecond > 0, "Invalid movement speed");
        _target = target; _speed = unitsPerSecond;
        _state = target == _position ? State.Idle : State.Walking;
    }
    void stop() { _state = State.Idle; }
    override void tick(uint milliseconds) {
        super.tick(milliseconds);
        if (_state != State.Walking || milliseconds == 0) return;
        auto dx = _target.x-_position.x, dy = _target.y-_position.y;
        auto distance = hypot(dx,dy);
        auto step = _speed*(milliseconds/1000.0);
        enforce(isFinite(distance) && isFinite(step), "Movement exceeds numeric range");
        if (step >= distance) { _position = _target; _state = State.Idle; }
        else { _position.x += dx/distance*step; _position.y += dy/distance*step; }
    }
    @property Position target() const { return _target; }
}
