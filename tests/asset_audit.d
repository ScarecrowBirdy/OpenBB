/// Headless corpus probe: real OpenBB APIs, no graphical dependency.
module asset_audit;
import openbb.io.boxfile;
import openbb.io.mfbfile;
import openbb.io.m10file;
import openbb.io.fatfile;
import std.file;
import std.path;
import std.json;
import std.digest.sha;
import std.string : toLower;
import std.stdio : stderr;

string hash(const(ubyte)[] bytes) { return toLower(toHexString(sha256Of(bytes))); }
int main(string[] args)
{
    try {
        JSONValue[] records, banks;
        foreach (file; dirEntries(args[1], "*.BOX", SpanMode.shallow)) {
            auto box = new BOXFile(file.name);
            foreach (i; 0..box.numFiles) {
                auto name = box.entryName(i);
                try {
                    JSONValue r = JSONValue.emptyObject;
                    r["archive"] = baseName(file.name); r["name"] = name;
                    r["sha256"] = hash(box[i]); r["bytes"] = box[i].length;
                    assert(box[toLower(name)] == box[i]);
                    if (toLower(extension(name)) == ".mfb") {
                        auto mfb = new MFBFile(box[i]);
                        r["width"] = mfb.width; r["height"] = mfb.height;
                        r["origin"] = JSONValue([JSONValue(mfb.originX),JSONValue(mfb.originY)]);
                        JSONValue[] frames;
                        foreach (j; 0..mfb.numSprites) frames ~= JSONValue(hash(mfb.frameIndices(j)));
                        r["frames"] = JSONValue(frames);
                    } else if (toLower(extension(name)) == ".m10") {
                        auto m10 = new M10File(box[i]);
                        auto wav = m10.toWav();
                        r["wav_sha256"] = hash(wav); r["wav_bytes"] = wav.length;
                        r["samples"] = m10.sampleCount;
                    }
                    records ~= r;
                } catch (Exception e) { throw new Exception(file.name ~ "/" ~ name ~ ": " ~ e.msg,e); }
            }
        }
        foreach (file; dirEntries(args[1], "*.FAT", SpanMode.shallow)) {
            auto fat = new FATFile(file.name);
            JSONValue b = JSONValue.emptyObject;
            b["file"] = baseName(file.name);
            JSONValue[] hashes;
            foreach (i; 0..fat.numFiles) hashes ~= JSONValue(hash(cast(const(ubyte)[])fat[i]));
            b["payloads"] = JSONValue(hashes); banks ~= b;
        }
        JSONValue result = JSONValue.emptyObject;
        result["entries"] = JSONValue(records); result["fat"] = JSONValue(banks);
        std.file.write(args[2], result.toPrettyString());
        return 0;
    } catch (Exception e) { stderr.writeln(e.msg); return 1; }
}
