/// CLI integration without Python or proprietary game files.
module cli_tests;
import std.file : write, read, exists, mkdir, rmdirRecurse, tempDir, getcwd;
import std.path : buildPath, absolutePath;
import std.process : execute;
import std.uuid : randomUUID;
import std.algorithm.searching : canFind, startsWith;
import std.exception : enforce;

ubyte[] boxEntry(string name, const(ubyte)[] payload) {
    auto data = new ubyte[532+payload.length];
    data[0..name.length] = cast(ubyte[])name;
    foreach (i; 0..4) data[528+i] = cast(ubyte)(payload.length >> (8*i));
    data[532..$] = payload; return data;
}
ubyte[] boxHeader() { return ['B','O','X',0x97,0,0,1,0]; }
void check(string exe, string[] args, int status, string message = "") {
    auto result = execute([exe] ~ args);
    enforce(result.status == status, "Wrong exit code: " ~ exe ~ " " ~ result.output);
    enforce(canFind(result.output,message), "Missing diagnostic: " ~ message ~ " / " ~ result.output);
}
void main() {
    // Only this unique directory, created by this test, is removed at scope exit.
    auto temp = absolutePath(tempDir());
    auto root = buildPath(temp,"openbb-cli-" ~ randomUUID().toString());
    enforce(root.startsWith(temp) && root != temp, "Invalid temporary test root");
    mkdir(root); scope(exit) rmdirRecurse(root);
    auto working = getcwd();
    auto bin = absolutePath("bin");
    auto input = buildPath(root,"mixed input.BOX");
    ubyte[] mfb = cast(ubyte[])"MFB101".dup;
    mfb ~= [2,0,1,0,0,0,0,0,0,0,1,0,7,9];
    ubyte[] pt = ['P','T',0,0,19,0,0,0,0xfd,0x83,1,9,0x85,2,0x10,0,0x8a,0,0xff];
    pt ~= new ubyte[5000];
    auto data = boxHeader() ~ boxEntry("note.txt",[42]) ~ boxEntry("Sprite.MfB",mfb) ~ boxEntry("Speech.m10",pt);
    write(input,data);
    foreach (tool; ["unbox","mfbdecoder","m10decoder"]) {
        auto exe = buildPath(bin,tool ~ ".exe");
        check(exe,["--help"],0,"Usage:");
        check(exe,[],2,"Usage:");
        check(exe,["--unknown"],2,"Usage:");
        auto output = buildPath(root,tool ~ " output");
        check(exe,[input,output],0);
        assert(exists(buildPath(output,tool == "unbox" ? "note.txt" : tool == "mfbdecoder" ? "Sprite.png" : "Speech.wav")));
        check(exe,[input,output],1,"Output already exists");
        check(exe,[buildPath(root,"missing.box"),buildPath(root,"missing-" ~ tool)],1,"Input is not a file");
    }
    assert(cast(ubyte[])read(input) == data && getcwd() == working);
    foreach (tool; ["mfbdecoder","m10decoder"]) {
        auto exe = buildPath(bin,tool ~ ".exe");
        auto ext = tool == "mfbdecoder" ? ".mfb" : ".m10";
        auto source = buildPath(root,tool ~ ".box");
        auto output = buildPath(root,"bad-" ~ tool);
        write(source,boxHeader() ~ boxEntry("broken" ~ ext,[0]));
        check(exe,[source,output],1,"entry #0 (broken" ~ ext ~ ")");
        assert(!exists(buildPath(output,tool == "mfbdecoder" ? "broken.png" : "broken.wav")));
        write(source,boxHeader() ~ boxEntry("note.txt",[42]));
        auto empty = buildPath(root,"empty-" ~ tool);
        check(exe,[source,empty],1,"No " ~ ext ~ " entries"); assert(!exists(empty));
        write(source,boxHeader() ~ boxEntry("../escape" ~ ext,[0]));
        auto unsafe = buildPath(root,"unsafe-" ~ tool);
        check(exe,[source,unsafe],1,"Unsafe output name"); assert(!exists(unsafe));
        write(source,boxHeader() ~ boxEntry("Foo" ~ ext,[0]) ~ boxEntry("foo" ~ ext,[0]));
        auto collision = buildPath(root,"collision-" ~ tool);
        check(exe,[source,collision],1,"Output name collision"); assert(!exists(collision));
    }
    // A malformed later resource must return failure with context, even if an
    // earlier resource was successfully written (documented partial-directory policy).
    write(input,boxHeader() ~ boxEntry("ok.mfb",mfb) ~ boxEntry("bad.mfb",[0]));
    auto partial = buildPath(root,"partial");
    check(buildPath(bin,"mfbdecoder.exe"),[input,partial],1,"entry #1 (bad.mfb)");
    assert(exists(buildPath(partial,"ok.png")) && !exists(buildPath(partial,"bad.png")));
    import std.stdio : writeln;
    writeln("CLI integration tests passed.");
}
