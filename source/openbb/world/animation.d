/// Tick-driven frame selection; no texture, timer, or rendering dependency.
module openbb.world.animation;
import std.exception : enforce;

struct Animation {
private:
    uint _start, _end = 1, _frame, _frameMilliseconds = 100;
    ulong _remainder;
    bool _playing;
public:
    void play(uint start, uint end, uint frameMilliseconds = 100) {
        enforce(start < end && frameMilliseconds > 0, "Invalid animation range or frame duration");
        _start = start; _end = end; _frame = start;
        _frameMilliseconds = frameMilliseconds; _remainder = 0; _playing = true;
    }
    void stop() { _playing = false; }
    void resume() { _playing = true; }
    void seek(uint frame) {
        enforce(frame >= _start && frame < _end, "Animation frame outside clip");
        _frame = frame; _remainder = 0;
    }
    void tick(uint milliseconds) {
        if (!_playing) return;
        const elapsed = _remainder + milliseconds;
        const steps = elapsed / _frameMilliseconds;
        _remainder = elapsed % _frameMilliseconds;
        _frame = _start + cast(uint)((cast(ulong)(_frame-_start) + steps) % (_end-_start));
    }
    @property uint frame() const { return _frame; }
    @property bool playing() const { return _playing; }
}
