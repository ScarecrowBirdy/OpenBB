/// Generic prototype storage; resource names are not native object/category IDs.
module openbb.world.inventory;
import std.exception : enforce;
import std.algorithm.sorting : sort;
struct InventoryItem { string resource; uint quantity; }
final class Inventory {
private:
    uint[string] _items;
public:
    uint quantity(string resource) const {
        auto value = resource in _items;
        return value is null ? 0 : *value;
    }
    void add(string resource, uint amount) {
        enforce(resource.length > 0, "Empty inventory resource");
        enforce(amount <= uint.max-quantity(resource), "Inventory overflow");
        if (amount) _items[resource] = quantity(resource)+amount;
    }
    void remove(string resource, uint amount) {
        enforce(amount <= quantity(resource), "Insufficient inventory");
        auto remaining = quantity(resource)-amount;
        if (remaining) _items[resource] = remaining;
        else _items.remove(resource);
    }
    void transferTo(Inventory target, string resource, uint amount) {
        enforce(target !is null && resource.length > 0, "Invalid inventory transfer");
        enforce(amount <= quantity(resource), "Insufficient inventory");
        if (target is this) return;
        // Validate/add first, so target overflow cannot discard source goods.
        target.add(resource,amount);
        remove(resource,amount);
    }
    InventoryItem[] snapshot() const {
        InventoryItem[] result;
        foreach (key, count; _items) result ~= InventoryItem(key,count);
        sort!((a,b) => a.resource < b.resource)(result);
        return result;
    }
}
