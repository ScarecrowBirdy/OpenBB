/// Beasts & Bumpkins sequential BOX reader. See docs/asset-tools.md.
module openbb.io.boxfile;
import std.exception : enforce;
import std.file : read;
import std.string : toLower;
import std.stdio : File;
import std.algorithm.searching : countUntil;

struct EntryTime { ushort year, month, dayofweek, day, hour, minute, second, milliseconds; }
private struct Entry {
    string name, path;
    EntryTime time;
    size_t headerOffset, offset, size;
}
final class BOXFile {
    private string _filename;
    private ubyte[] _data;
    private Entry[] _entries;
    private size_t[string] _names;
    this(string filename) { _filename = filename; readArchive(); }
    this(const(ubyte)[] bytes) { _data = bytes.dup; parse(); }
    void readArchive() { _data = cast(ubyte[])read(_filename); parse(); }
    private uint number(size_t at, size_t width) const {
        uint value;
        foreach (i; 0 .. width) value |= cast(uint)_data[at+i] << (8*i);
        return value;
    }
    private string text(size_t at) const {
        auto field = _data[at .. at+256];
        auto end = countUntil(field, cast(ubyte)0);
        enforce(end >= 0, "BOX string is not NUL-terminated");
        return cast(string)field[0 .. end].idup;
    }
    private void parse() {
        _entries = null; _names = null;
        enforce(_data.length >= 8 && _data[0..3] == cast(ubyte[])"BOX", "Invalid BOX header");
        size_t pos = 8;
        while (pos < _data.length) {
            enforce(_data.length-pos >= 532, "Truncated BOX entry header");
            auto size = number(pos+528, 4);
            enforce(size <= int.max && size <= _data.length-pos-532, "Invalid BOX entry length");
            Entry e;
            e.name = text(pos); e.path = text(pos+256);
            e.time = EntryTime(cast(ushort)number(pos+512,2), cast(ushort)number(pos+514,2),
                cast(ushort)number(pos+516,2), cast(ushort)number(pos+518,2),
                cast(ushort)number(pos+520,2), cast(ushort)number(pos+522,2),
                cast(ushort)number(pos+524,2), cast(ushort)number(pos+526,2));
            e.headerOffset = pos; e.offset = pos+532; e.size = size;
            auto key = toLower(e.name);
            // Original game: first case-insensitive match wins.
            if (!(key in _names)) _names[key] = _entries.length;
            _entries ~= e; pos += 532+size;
        }
    }
    const(ubyte)[] opIndex(string name) const {
        auto index = toLower(name) in _names;
        enforce(index !is null, "BOX entry not found: " ~ name);
        return this[*index];
    }
    const(ubyte)[] opIndex(size_t index) const {
        enforce(index < _entries.length, "BOX entry index out of range");
        auto e = _entries[index]; return _data[e.offset .. e.offset+e.size];
    }
    string[] fileList() const {
        string[] result;
        foreach (e; _entries) result ~= e.name;
        return result;
    }
    string entryName(size_t index) const { return _entries[index].name; }
    string entryPath(size_t index) const { return _entries[index].path; }
    EntryTime entryDate(size_t index) const { return _entries[index].time; }
    const(ubyte)[] archiveHeader() const { return _data[0..8]; }
    const(ubyte)[] entryHeader(size_t index) const {
        auto pos = _entries[index].headerOffset; return _data[pos .. pos+532];
    }
    @property size_t numFiles() const { return _entries.length; }
    void dump(string filename) const {
        auto output = File(filename, "w");
        foreach (e; _entries) output.writefln("%s\t%s\t%d", e.name, e.path, e.size);
    }
}
