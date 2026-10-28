module openbb.tools.cli;
import std.exception : enforce;
import std.file : exists, isFile;
import std.path : absolutePath, buildNormalizedPath;
import std.string : toLower, indexOf;
import std.stdio : writeln;

struct Options { string input, output; }
Options options(string[] args)
{
    enforce(args.length == 3, "Usage: " ~ args[0] ~ " INPUT.BOX NEW_OUTPUT_DIRECTORY");
    auto result = Options(absolutePath(args[1]), absolutePath(args[2]));
    enforce(isFile(result.input), "Input is not a file: " ~ result.input);
    enforce(!exists(result.output), "Output already exists; choose a new directory: " ~ result.output);
    return result;
}
void validateNames(string[] names)
{
    bool[string] seen;
    foreach (name; names)
    {
        enforce(name.length > 0 && name != "." && name != "..", "Empty/invalid output name");
        foreach (c; name)
            enforce(c >= 32 && "<>:\"/\\|?*".indexOf(c) < 0, "Unsafe output name: " ~ name);
        enforce(name[$-1] != '.' && name[$-1] != ' ', "Unsafe output name: " ~ name);
        auto key = toLower(name);
        auto dot = key.indexOf('.');
        auto stem = dot < 0 ? key : key[0..dot];
        bool reserved = stem == "con" || stem == "prn" || stem == "aux" || stem == "nul";
        if (stem.length == 4 && (stem[0..3] == "com" || stem[0..3] == "lpt") &&
            stem[3] >= '1' && stem[3] <= '9') reserved = true;
        enforce(!reserved, "Reserved output name: " ~ name);
        enforce(!(key in seen), "Output name collision: " ~ name);
        seen[key] = true;
    }
}
string outputPath(Options o, string name) { return buildNormalizedPath(o.output, name); }
bool help(string[] args)
{
    if (args.length == 2 && (args[1] == "--help" || args[1] == "-h"))
    {
        writeln("Usage: ", args[0], " INPUT.BOX NEW_OUTPUT_DIRECTORY");
        return true;
    }
    return false;
}
