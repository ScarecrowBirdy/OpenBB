module openbb.world.building;
import openbb.world.staticentity;
import openbb.world.geometry;
/// Prototype construction state; native construction stages are not implemented.
enum ConstructionStage { site, toppingOut, complete }
class Building : StaticEntity {
private:
    ConstructionStage _stage;
public:
    this(uint id, Position position, Size footprint) { super(id,position,footprint); }
    void prepareTopOut() { _stage = ConstructionStage.toppingOut; }
    void buildFinished() { _stage = ConstructionStage.complete; }
    @property ConstructionStage stage() const { return _stage; }
}
