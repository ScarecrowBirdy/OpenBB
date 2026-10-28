module openbb.world.entity;
import openbb.world.geometry;
import openbb.world.animation;
import openbb.world.inventory;
import std.exception : enforce;

// Generic state only: no recovered job selection or production rules yet.
enum JobPhase { idle, assigned, working }
struct JobState { string name; uint targetId; JobPhase phase; }
enum State { Idle, Walking, InBuilding, Fighting }
struct EntitySnapshot {
    uint id;
    Position position;
    Size size;
    uint layer;
    string resource;
    uint frame;
    State state;
    JobState job;
    InventoryItem[] inventory;
}

class Entity {
protected:
    Position _position;
    State _state;
private:
    uint _id;
    JobState _job;
    Inventory _inventory;
public:
    Size size;
    uint layer;
    string resource;
    Animation animation;
    this(uint id, Position position = Position(), Size size = Size()) {
        enforce(id > 0, "Entity ID must be nonzero"); position.validate();
        _id = id; _position = position; this.size = size;
        _inventory = new Inventory;
    }
    void tick(uint milliseconds) { animation.tick(milliseconds); }
    void assignJob(string name, uint targetId) {
        enforce(name.length > 0 && targetId > 0, "Invalid job assignment");
        _job = JobState(name,targetId,JobPhase.assigned);
    }
    void startJob() {
        enforce(_job.phase == JobPhase.assigned, "No assigned job to start");
        _job.phase = JobPhase.working;
    }
    void clearJob() { _job = JobState.init; }
    EntitySnapshot snapshot() const {
        return EntitySnapshot(_id,_position,size,layer,resource,animation.frame,_state,_job,_inventory.snapshot());
    }
    @property Inventory inventory() { return _inventory; }
    @property const(Inventory) inventory() const { return _inventory; }
    @property uint id() const { return _id; }
    @property Position position() const { return _position; }
    @property void position(Position value) { value.validate(); _position = value; }
    @property State state() const { return _state; }
    @property JobState job() const { return _job; }
}
