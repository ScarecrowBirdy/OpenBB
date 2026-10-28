module mfbdecoder;

import openbb.io.boxfile;
import openbb.io.mfbfile;
import openbb.io.palette;
import openbb.tools.cli;
import png;
import std.stdio : writeln, stderr;
import std.string : toLower;
import std.file : mkdir, write;
import std.path : extension, stripExtension;
import std.exception : enforce;

int main(string[] args)
{
    if (help(args)) return 0;
    try
    {
        auto o = options(args);
        auto box = new BOXFile(o.input);
        string[] names;
        foreach (name; box.fileList())
        {
            enforce(toLower(extension(name)) == ".mfb", "Expected only MFB resources");
            names ~= stripExtension(name) ~ ".png";
        }
        validateNames(names);
        mkdir(o.output);
        foreach (i; 0..box.numFiles)
        {
            switch (toLower(stripExtension(box.entryName(i))))
            {
                case "m1back": case "m2back": case "m3back": case "m4back":
                case "m5back": case "m7back": case "m9back": case "m11back":
                case "loading": case "credits": case "yakoff":
                    usePalette(Palette.Loading); break;
                case "mission": usePalette(Palette.Mission); break;
                default: usePalette(Palette.Main); break;
            }
            auto mfb = new MFBFile(box[i]);
            auto sheet = mfb[];
            write(outputPath(o,names[i]),toPNG(mfb.spriteSheetWidth*mfb.width,
                mfb.spriteSheetHeight*mfb.height,sheet));
        }
        writeln("Decoded ",box.numFiles," sprite sheets to ",o.output);
        return 0;
    }
    catch (Exception e) { stderr.writeln(e.msg); return 1; }
}
