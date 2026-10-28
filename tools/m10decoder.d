module m10decoder;
import openbb.io.boxfile;
import openbb.io.m10file;
import openbb.tools.cli;
import std.file : mkdir, write;
import std.stdio : writeln;
int main(string[] args) {
    return runTool(args, (o) {
        auto box = new BOXFile(o.input);
        auto entries = selectEntries(box,".m10",".wav");
        mkdir(o.output);
        foreach (entry; entries) withEntry(entry.index,entry.name, () {
            write(outputPath(o,entry.output),new M10File(box[entry.index]).toWav());
        });
        writeln("Decoded ",entries.length," speech files to ",o.output);
    });
}
