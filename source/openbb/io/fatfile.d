/// FAT sound-bank reader. Directory metadata is preserved without assuming
/// that every entry is PCM; opIndex explicitly requests signed 16-bit LE samples.
module openbb.io.fatfile;
import std.file : read;
import std.exception : enforce;
import openbb.io.binary : readLE;

struct FATEntry { uint offset, size, type, flag; }
final class FATFile
{
private:
    FATEntry[] _entries;
    ubyte[] _data;
public:
    this(string filename) { this(cast(ubyte[])read(filename)); }
    this(const(ubyte)[] data)
    {
        enforce(data.length >= 8 && data[0..4] == cast(ubyte[])"0.30", "Invalid/truncated FAT header");
        auto count = readLE(data,4,4);
        enforce(count <= (data.length-8)/16, "Truncated FAT directory");
        const end = 8+cast(size_t)count*16;
        _entries.length = count;
        foreach (i, ref entry; _entries)
        {
            const at = 8+i*16;
            entry = FATEntry(readLE(data,at,4),readLE(data,at+4,4),
                readLE(data,at+8,4),readLE(data,at+12,4));
            enforce(entry.offset >= end && entry.offset <= data.length && entry.size <= data.length-entry.offset,
                "FAT payload outside file");
        }
        _data = data.dup;
    }
    FATEntry entryInfo(size_t index) const
    {
        enforce(index < _entries.length, "FAT entry index out of range");
        return _entries[index];
    }
    const(ubyte)[] entryBytes(size_t index) const
    {
        auto entry = entryInfo(index);
        return _data[entry.offset..cast(size_t)entry.offset+entry.size];
    }
    const(short)[] opIndex(size_t index) const
    {
        auto data = entryBytes(index);
        enforce(data.length % 2 == 0, "FAT entry has an incomplete 16-bit sample");
        auto samples = new short[data.length/2];
        foreach (i, ref sample; samples) sample = cast(short)readLE(data,i*2,2);
        return samples;
    }
    @property uint numFiles() const { return cast(uint)_entries.length; }
}
