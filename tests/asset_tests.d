module asset_tests;
import openbb.io.boxfile;
import openbb.io.mfbfile;
import openbb.io.m10file;
import openbb.tools.cli;
import std.exception : assertThrown;
import std.stdio : writeln;

ubyte[] boxEntry(string name, ubyte[] payload)
{
    auto data = new ubyte[532+payload.length];
    data[0..name.length] = cast(ubyte[])name;
    foreach (i; 0..4) data[528+i] = cast(ubyte)(payload.length >> (8*i));
    data[532..$] = payload;
    return data;
}
ubyte[] boxHeader() { return ['B','O','X',0x97,0,0,1,0]; }

unittest
{
    auto raw = boxHeader() ~ boxEntry("Foo.txt",[1,2,3]) ~ boxEntry("foo.TXT",[4]);
    auto box = new BOXFile(raw);
    assert(box.numFiles == 2 && box["FOO.TXT"] == [1,2,3]);
    assert(box[1] == [4] && box.entryName(0) == "Foo.txt");
    assert(box.archiveHeader()[3] == 0x97);
    assert(box.entryHeader(0).length == 532);
    assert(new BOXFile(boxHeader()).numFiles == 0);
    assert(new BOXFile(boxHeader() ~ boxEntry("empty",[]))[0].length == 0);
    assertThrown!Exception(new BOXFile(raw[0..$-1]));
    assertThrown!Exception(new BOXFile(boxHeader() ~ [cast(ubyte)0]));
    assertThrown!Exception(new BOXFile(cast(ubyte[])"BAD"));
    raw[8+528..8+532] = 0xff;
    assertThrown!Exception(new BOXFile(raw));
}

unittest
{
    validateNames(["safe.MFB","also safe.txt"]);
    foreach (name; ["../escape", "x/y", "x\\y", "CON", "NUL.txt", "a:", "a.", "a ", ""])
        assertThrown!Exception(validateNames([name]));
    assertThrown!Exception(validateNames(["Foo","foo"]));
}

unittest
{
    // Two raw pixels, negative x origin; accepts historical MFB100 as well.
    ubyte[] header = cast(ubyte[])"MFB101".dup;
    header ~= [2,0,1,0,255,255,0,0,0,0,1,0];
    auto mfb = new MFBFile(header ~ cast(ubyte[])[7,9]);
    assert(mfb.originX == -1 && mfb.frameIndices(0) == [7,9]);
    assertThrown!Exception(new MFBFile(header ~ cast(ubyte[])[7]));
    header[5] = '0';
    assert(new MFBFile(header ~ cast(ubyte[])[7,9]).numSprites == 1);
    header[14] = 2;
    assert(new MFBFile(header ~ cast(ubyte[])[2,0,0,0,0,2]).frameIndices(0) == [0,0]);
    assertThrown!Exception(new MFBFile(header ~ cast(ubyte[])[2,0,0,0,0,3]));
    assertThrown!Exception(new MFBFile(header ~ cast(ubyte[])[1,0,0,0,0]));
    assertThrown!Exception(new MFBFile(cast(ubyte[])"MFB"));
}

unittest
{
    assertThrown!Exception(new M10File([]));
    assertThrown!Exception(new M10File(cast(ubyte[])"PT"));
    ubyte[] bad = ['P','T',0,0,255,255,255,127];
    assertThrown!Exception(new M10File(bad));
    // Synthetic all-zero codec input: exact output-block boundary must not emit
    // a 4097th sample on the next call (four retail files exposed this bug).
    ubyte[] pt = ['P','T',0,0,19,0,0,0,0xfd,0x83,1,9,0x85,2,0x10,0,0x8a,0,0xff];
    auto speech = new M10File(pt ~ new ubyte[5000]);
    assert(speech.toWav().length == 44+4096*2);
    short[4096] samples;
    assert(speech.Decode(samples) == 0);
    assertThrown!Exception(new M10File(pt ~ new ubyte[2]).toWav());
}
void main() { writeln("Asset regression tests passed (BOX, MFB, PT and output policy)."); }
