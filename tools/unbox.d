module unbox;
import openbb.io.boxfile;
import openbb.tools.cli;
import std.file : mkdir, write;
import std.stdio : writeln;
import std.json;
import std.digest.sha;
import std.string : toLower;
int main(string[] args) {
    return runTool(args, (o) {
        auto box = new BOXFile(o.input);
        validateNames(box.fileList() ~ ["_box_manifest.json"]);
        mkdir(o.output);
        JSONValue[] entries;
        foreach (i; 0..box.numFiles) {
            auto name = box.entryName(i); auto data = box[i];
            withEntry(i,name, () { write(outputPath(o,name),data); });
            JSONValue e = JSONValue.emptyObject;
            e["index"] = i; e["name"] = name; e["path"] = box.entryPath(i);
            e["header_hex"] = toLower(toHexString(box.entryHeader(i)));
            e["bytes"] = data.length; e["sha256"] = toLower(toHexString(sha256Of(data)));
            entries ~= e;
        }
        JSONValue m = JSONValue.emptyObject;
        m["archive_header_hex"] = toLower(toHexString(box.archiveHeader()));
        m["entries"] = JSONValue(entries);
        write(outputPath(o,"_box_manifest.json"),m.toPrettyString());
        writeln("Extracted ",box.numFiles," entries to ",o.output);
    });
}
