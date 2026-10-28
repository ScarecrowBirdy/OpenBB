module m10decoder;
import openbb.io.boxfile;
import openbb.io.m10file;
import openbb.tools.cli;
import std.file : mkdir, write;
import std.path : extension, stripExtension;
import std.string : toLower;
import std.stdio : writeln, stderr;
import std.exception : enforce;
int main(string[] args) {
    if (help(args)) return 0;
    try {
        auto o = options(args); auto box = new BOXFile(o.input);
        string[] names;
        foreach (name; box.fileList()) {
            enforce(toLower(extension(name)) == ".m10", "Expected only M10 resources");
            names ~= stripExtension(name) ~ ".wav";
        }
        validateNames(names); mkdir(o.output);
        foreach (i; 0..box.numFiles)
            write(outputPath(o,names[i]),new M10File(box[i]).toWav());
        writeln("Decoded ",box.numFiles," speech files to ",o.output);
        return 0;
    } catch (Exception e) { stderr.writeln(e.msg); return 1; }
}
