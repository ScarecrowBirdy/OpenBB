module openbb.tools.cli;
import std.exception : enforce;
import std.file : exists, isFile;
import std.path : absolutePath, buildNormalizedPath, baseName, extension, stripExtension;
import std.string : toLower, indexOf;
import std.stdio : writeln, stderr;
import openbb.io.boxfile : BOXFile;

enum ExitCode { success = 0, failure = 1, usage = 2 }
class UsageException : Exception { this(string message) { super(message); } }
string usage(string program) { return "Usage: " ~ program ~ " INPUT.BOX NEW_OUTPUT_DIRECTORY"; }

/// Shared process boundary. Readers throw; only the application reports errors.
int runTool(string[] args, void delegate(Options) action)
{
    auto program = args.length ? baseName(args[0]) : "asset-tool";
    if (help(args)) return ExitCode.success;
    try { action(options(args)); return ExitCode.success; }
    catch (UsageException e) { stderr.writeln(program, ": ", e.msg); return ExitCode.usage; }
    catch (Exception e) {
        stderr.writeln(program, ": ", args.length > 1 ? args[1] ~ ": " : "", e.msg);
        return ExitCode.failure;
    }
}

struct Selection { size_t index; string name, output; }
Selection[] selectEntries(BOXFile box, string inputExtension, string outputExtension)
{
    Selection[] selected;
    string[] names;
    foreach (i; 0..box.numFiles) {
        auto name = box.entryName(i);
        if (toLower(extension(name)) != inputExtension) continue;
        auto output = stripExtension(name) ~ outputExtension;
        selected ~= Selection(i,name,output); names ~= output;
    }
    enforce(selected.length > 0, "No " ~ inputExtension ~ " entries found in archive");
    validateNames(names);
    return selected;
}

void withEntry(size_t index, string name, void delegate() action)
{
    import std.conv : to;
    try { action(); }
    catch (Exception e) { throw new Exception("entry #" ~ index.to!string ~ " (" ~ name ~ "): " ~ e.msg, e); }
}

struct Options { string input, output; }
Options options(string[] args)
{
    if (args.length != 3) throw new UsageException(usage(args.length ? args[0] : "asset-tool"));
    auto result = Options(absolutePath(args[1]), absolutePath(args[2]));
    enforce(exists(result.input) && isFile(result.input), "Input is not a file: " ~ result.input);
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
        writeln(usage(args[0]));
        return true;
    }
    return false;
}
