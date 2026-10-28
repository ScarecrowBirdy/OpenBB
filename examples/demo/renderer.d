/// Legacy DSFML adapter. Simulation and scene construction live outside DSFML.
module renderer;
import openbb.graphics.scene : DrawCommand;
import dsfml.graphics.image;
import dsfml.graphics.sprite;
import dsfml.graphics.irendertarget;
import dsfml.graphics.rect;
import dsfml.system.vector;
import std.exception : enforce;

class DemoRenderer {
    struct Sheet { Image image; uint width, height, count; }
    private Sheet[string] _sheets;
    void addSheet(string name, Image image, uint width, uint height, uint count) {
        enforce(image !is null && width > 0 && height > 0 && count > 0, "Invalid sprite sheet");
        enforce(cast(ulong)(image.width/width)*(image.height/height) >= count, "Incomplete sprite sheet");
        _sheets[name] = Sheet(image,width,height,count);
    }
    // Reads commands only; repeated draws do not tick or mutate world state.
    void draw(IRenderTarget target, const(DrawCommand)[] commands) {
        foreach (command; commands) {
            auto sheet = command.resource in _sheets;
            enforce(sheet !is null && command.frame < sheet.count, "Unknown scene resource/frame");
            auto sprite = new Sprite(sheet.image);
            auto columns = sheet.image.width/sheet.width;
            sprite.subRect = IntRect((command.frame%columns)*sheet.width,
                (command.frame/columns)*sheet.height,sheet.width,sheet.height);
            sprite.position = Vector2f(cast(float)command.position.x,cast(float)command.position.y);
            target.draw(sprite);
        }
    }
}
