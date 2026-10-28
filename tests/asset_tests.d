module asset_tests;
import openbb.io.boxfile;
import openbb.io.mfbfile;
import openbb.io.m10file;
import openbb.io.fatfile;
import openbb.io.palette : getPalette, Palette;
import openbb.tools.cli;
import std.exception : assertThrown, collectException;
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


// Mutated files must fail with catchable exceptions, including in release builds.
unittest
{
    auto bytes = boxHeader() ~ boxEntry("Name",[1,2,3]);
    foreach (end; 0..bytes.length)
        if (end != 8) assertThrown!Exception(new BOXFile(bytes[0..end]));
    auto box = new BOXFile(bytes);
    assertThrown!Exception(box[1]);
    assertThrown!Exception(box["missing"]);
    assertThrown!Exception(box.entryName(1));
    assertThrown!Exception(box.entryPath(1));
    assertThrown!Exception(box.entryDate(1));
    assertThrown!Exception(box.entryHeader(1));
    bytes[8..264] = 'x';
    assertThrown!Exception(new BOXFile(bytes));
    bytes = boxHeader() ~ boxEntry("Name",[1]);
    bytes[264..520] = 'x';
    assertThrown!Exception(new BOXFile(bytes));
    // Unknown code-page bytes remain inspectable; ASCII suffix folding still works.
    auto name = cast(string)(cast(ubyte[])[0xff,'A']).idup;
    box = new BOXFile(boxHeader() ~ boxEntry(name,[42]));
    assert(box[cast(string)(cast(ubyte[])[0xff,'a']).idup] == [42]);
    bytes = boxHeader() ~ boxEntry("Owned",[7]);
    box = new BOXFile(bytes); bytes[$-1] = 99;
    assert(box[0] == [7]);
}

unittest
{
    import std.file : write, remove, tempDir;
    import std.path : buildPath;
    import std.uuid : randomUUID;
    auto path = buildPath(tempDir(), "openbb-reload-" ~ randomUUID().toString() ~ ".box");
    write(path,boxHeader() ~ boxEntry("original",[7]));
    scope(exit) remove(path);
    auto box = new BOXFile(path);
    write(path,boxHeader() ~ boxEntry("partial",[8]) ~ cast(ubyte[])[0]);
    assertThrown!Exception(box.readArchive());
    assert(box.numFiles == 1 && box["ORIGINAL"] == [7]);
}

unittest
{
    // Raw frames use their own first pixel as key, not the last frame's key.
    ubyte[] header = cast(ubyte[])"MFB101".dup;
    header ~= [2,0,1,0,0,128,255,127,1,0,2,0];
    auto raw = header ~ cast(ubyte[])[7,9,9,7];
    auto mfb = new MFBFile(raw);
    assert(mfb.originX == short.min && mfb.originY == short.max);
    assert(mfb.transparencyIndex(0) == 7 && mfb.transparencyIndex(1) == 9);
    assert(mfb[0][0].a == 0 && mfb[0][1].a == 255);
    assert(mfb[1][0].a == 0 && mfb[1][1].a == 255);
    auto sheet = mfb[];
    assert(sheet[0].a == 0 && sheet[1].a == 255 && sheet[2].a == 0 && sheet[3].a == 255);
    assertThrown!Exception(mfb[2]);
    assertThrown!Exception(mfb.frameIndices(2));
    assertThrown!Exception(mfb.transparencyIndex(2));
    foreach (end; 0..raw.length) assertThrown!Exception(new MFBFile(raw[0..end]));
    assert(new MFBFile(raw ~ cast(ubyte[])[42]).trailingData() == [42]);

    // Compressed frames share the FIRST decoded pixel; a zero-length marker
    // prefix deliberately makes that pixel different from the RLE marker.
    header[14] = 3;
    auto encoded = header ~ cast(ubyte[])[4,0,0,0,0,0,7,9, 4,0,0,0,1,0,9,7];
    mfb = new MFBFile(encoded);
    assert(mfb.frameIndices(0) == [7,9] && mfb.frameIndices(1) == [9,7]);
    assert(mfb.transparencyIndex(0) == 7 && mfb.transparencyIndex(1) == 7);
    assert(mfb[0][0].a == 0 && mfb[1][0].a == 255 && mfb[1][1].a == 0);
    sheet = mfb[];
    assert(sheet[0].a == 0 && sheet[2].a == 255 && sheet[3].a == 0);
    foreach (end; 0..encoded.length) assertThrown!Exception(new MFBFile(encoded[0..end]));
    ubyte[2] pixels;
    assertThrown!Exception(MFBFile.unRLE([0,2,42], pixels));
    assertThrown!Exception(MFBFile.unRLE([0,0], pixels));
    header[6..10] = 0;
    assertThrown!Exception(new MFBFile(header));
    // Reject excessive declared allocation before allocating any frame pixels.
    header[6..10] = [255,127,255,127];
    assertThrown!Exception(new MFBFile(header));
}

unittest
{
    ubyte[] raw = cast(ubyte[])"0.30".dup;
    raw ~= [1,0,0,0, 24,0,0,0, 4,0,0,0, 99,0,0,0, 17,0,0,0, 0,128,255,127];
    auto bank = new FATFile(raw);
    assert(bank.numFiles == 1 && bank[0] == [short.min,short.max]);
    assert(bank.entryInfo(0).type == 99 && bank.entryInfo(0).flag == 17);
    assert(bank.entryBytes(0) == [0,128,255,127]);
    foreach (end; 0..raw.length) assertThrown!Exception(new FATFile(raw[0..end]));
    assertThrown!Exception(bank[1]);
    assertThrown!Exception(bank.entryBytes(1));
    assertThrown!Exception(bank.entryInfo(1));
    raw[24] = 42;
    assert(bank.entryBytes(0)[0] == 0);
    raw[12] = 3; // Raw inspection supports odd lengths; PCM conversion refuses.
    bank = new FATFile(raw[0..$-1]);
    assert(bank.entryBytes(0).length == 3);
    assertThrown!Exception(bank[0]);
    raw[8] = 23;
    assertThrown!Exception(new FATFile(raw));
    raw[8..12] = 255;
    assertThrown!Exception(new FATFile(raw));
    assert(new FATFile(cast(ubyte[])"0.30" ~ cast(ubyte[])[0,0,0,0]).numFiles == 0);
}

unittest
{
    ubyte[] header = ['P','T',0,0,19,0,0,0,0xfd,0x83,1,9,0x85,2,0x10,0,0x8a,0,0xff];
    auto stream = new ubyte[5000];
    auto wav = new M10File(header ~ stream).toWav();
    // Sample output must be independent of the caller's block size.
    auto decoder = new M10File(header ~ stream);
    short[37] chunk;
    short[] samples;
    uint count;
    while ((count = decoder.Decode(chunk)) != 0) samples ~= chunk[0..count];
    assert(cast(ubyte[])samples == wav[44..$]);
    assertThrown!Exception(decoder.toWav());
    foreach (end; 0..header.length) assertThrown!Exception(new M10File(header[0..end]));
    auto bad = header.dup; bad[11] = 8;
    assertThrown!Exception(new M10File(bad ~ stream));
    bad = header.dup; bad[10] = 255;
    assertThrown!Exception(new M10File(bad ~ stream));
    bad = header.dup; bad[18] = 0;
    assertThrown!Exception(new M10File(bad ~ stream));
    // First history lag occupies bits 79..86 after the codec header and tables.
    // A lag of 255 formerly underflowed the unsigned history index.
    foreach (bit; 79..87) stream[bit/8] |= cast(ubyte)(1 << (bit%8));
    auto error = collectException(new M10File(header ~ stream).toWav());
    assert(error !is null && error.msg == "Speech history reference precedes buffer");
}
void main() { writeln("Asset regression tests passed (BOX, MFB, FAT, PT and output policy)."); }

unittest {
    // Interleaved decode calls cannot change another export's palette.
    ubyte[] header = cast(ubyte[])"MFB101".dup;
    header ~= [2,0,1,0,0,0,0,0,0,0,1,0];
    auto a = new MFBFile(header ~ cast(ubyte[])[7,9]);
    auto b = new MFBFile(header ~ cast(ubyte[])[11,13]);
    auto main = a.sheet(Palette.Main);
    auto loading = a.sheet(Palette.Loading);
    assert(main != loading);
    b[0,Palette.Mission];
    assert(a[] == main && a.sheet(Palette.Loading) == loading);
    assert(a[0,Palette.Main] == main);
    assertThrown!Exception(getPalette(cast(Palette)255));
}
