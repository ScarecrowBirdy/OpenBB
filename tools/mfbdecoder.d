module mfbdecoder;
import openbb.io.boxfile;
import openbb.io.mfbfile;
import openbb.io.palette;
import openbb.io.png;
import openbb.tools.cli;
import std.file : mkdir, write;
import std.path : stripExtension;
import std.string : toLower;
import std.stdio : writeln;

// Inherited export palette policy; runtime effects are a separate renderer concern.
Palette exportPalette(string name) {
    switch (toLower(stripExtension(name))) {
        case "m1back": case "m2back": case "m3back": case "m4back":
        case "m5back": case "m7back": case "m9back": case "m11back":
        case "loading": case "credits": case "yakoff": return Palette.Loading;
        case "mission": return Palette.Mission;
        default: return Palette.Main;
    }
}
int main(string[] args) {
    return runTool(args, (o) {
        auto box = new BOXFile(o.input);
        auto entries = selectEntries(box,".mfb",".png");
        mkdir(o.output);
        foreach (entry; entries) withEntry(entry.index,entry.name, () {
            auto mfb = new MFBFile(box[entry.index]);
            auto pixels = mfb.sheet(exportPalette(entry.name));
            write(outputPath(o,entry.output),toPNG(mfb.spriteSheetWidth*mfb.width,
                mfb.spriteSheetHeight*mfb.height,pixels));
        });
        writeln("Decoded ",entries.length," sprite sheets to ",o.output);
    });
}
