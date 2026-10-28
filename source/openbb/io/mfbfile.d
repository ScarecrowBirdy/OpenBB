/// Indexed MFB sprites. See docs/asset-formats.md for color-key evidence.
module openbb.io.mfbfile;

import core.stdc.math : sqrtf, ceilf;
import std.file : read;
import std.exception : enforce;
import openbb.common : RGBA;
import openbb.io.binary : readLE;
import openbb.io.palette;

final class MFBFile
{
private:
    enum transparent = 1, compressed = 2;
    enum maxBytes = 256UL * 1024 * 1024;
    ushort _width, _height, _flags, _count;
    short _originX, _originY;
    ubyte[][] _frames;
    const(ubyte)[] _trailing;
    uint _sheetColumns, _sheetRows;

public:
    /// isMaptile is retained for source compatibility; decoding never crops rows.
    this(string filename, bool isMaptile = false)
    {
        this(cast(ubyte[])read(filename), isMaptile);
    }

    this(const(ubyte)[] data, bool isMaptile = false)
    {
        enforce(data.length >= 18 && data[0..3] == cast(ubyte[])"MFB", "Invalid/truncated MFB header");
        enforce(data[3..6] == cast(ubyte[])"100" || data[3..6] == cast(ubyte[])"101", "Unsupported MFB version");
        _width = cast(ushort)readLE(data,6,2);
        _height = cast(ushort)readLE(data,8,2);
        _originX = cast(short)readLE(data,10,2);
        _originY = cast(short)readLE(data,12,2);
        _flags = cast(ushort)readLE(data,14,2);
        _count = cast(ushort)readLE(data,16,2);
        enforce(_width > 0 && _height > 0 && _width <= 32767 && _height <= 32767 && _count > 0,
            "Invalid MFB dimensions/frame count");
        const pixels = cast(size_t)_width * _height;
        enforce(cast(ulong)pixels * _count <= maxBytes, "MFB exceeds indexed pixel limit (256 MiB)");
        size_t pos = 18;
        if (!(_flags & compressed))
            enforce(cast(ulong)pixels * _count <= data.length-pos, "Truncated raw MFB frames");
        else
            enforce(_count <= (data.length-pos)/5, "Truncated compressed MFB frames");
        _frames.length = _count;
        foreach (ref frame; _frames)
        {
            if (_flags & compressed)
            {
                auto length = readLE(data,pos,4); pos += 4;
                enforce(length > 0 && length <= data.length-pos, "Invalid MFB frame length");
                frame = new ubyte[pixels];
                unRLE(data[pos..pos+length],frame);
                pos += length;
            }
            else
            {
                frame = data[pos..pos+pixels].dup;
                pos += pixels;
            }
        }
        // Retail pspells.mfb has an extra byte after its last frame. Preserve it.
        _trailing = data[pos..$].idup;
    }

    /// Raw frames have individual surface keys. Compressed frames share the key
    /// sampled from the initial (frame zero) surface, not the final RLE marker.
    ubyte transparencyIndex(size_t index) const
    {
        enforce(index < _frames.length, "MFB frame index out of range");
        return _frames[(_flags & compressed) ? 0 : index][0];
    }

    RGBA[] opIndex(size_t index, Palette paletteIdx = Palette.Main)
    {
        enforce(index < _frames.length, "MFB frame index out of range");
        enforce(cast(ulong)_frames[index].length * RGBA.sizeof <= maxBytes,
            "MFB RGBA frame exceeds 256 MiB limit");
        auto palette = getPalette(paletteIdx);
        auto result = new RGBA[_frames[index].length];
        auto key = transparencyIndex(index);
        foreach (i, pixel; _frames[index])
            result[i] = (_flags & transparent) && pixel == key ? RGBA(0,0,0,0) : palette[pixel];
        return result;
    }

    /// Explicit per-call palette selection; opSlice defaults to the main palette.
    RGBA[] opSlice() { return sheet(Palette.Main); }
    RGBA[] sheet(Palette paletteIdx = Palette.Main)
    {
        auto palette = getPalette(paletteIdx);
        _sheetColumns = cast(uint)(sqrtf(cast(float)_count) + 0.5);
        _sheetRows = cast(uint)ceilf(cast(float)_count / _sheetColumns);
        const pixels = cast(ulong)_width * _height * _sheetColumns * _sheetRows;
        enforce(pixels * RGBA.sizeof <= maxBytes, "MFB RGBA sheet exceeds 256 MiB limit");
        auto result = new RGBA[cast(size_t)pixels];
        size_t cursor;
        foreach (row; 0.._sheetRows)
            foreach (y; 0.._height)
                foreach (col; 0.._sheetColumns)
                {
                    const frame = row*_sheetColumns+col;
                    foreach (x; 0.._width)
                    {
                        if (frame >= _count) { result[cursor++] = RGBA(255,0,255,255); continue; }
                        auto pixel = _frames[frame][y*_width+x];
                        result[cursor++] = (_flags & transparent) && pixel == transparencyIndex(frame)
                            ? RGBA(0,0,0,0) : palette[pixel];
                    }
                }
        return result;
    }

    static void unRLE(const(ubyte)[] input, ubyte[] output)
    {
        enforce(input.length > 0, "Empty MFB RLE frame");
        size_t cursor, written;
        const marker = input[0];
        while (written < output.length)
        {
            enforce(cursor < input.length, "MFB RLE underflow");
            auto pixel = input[cursor++];
            if (pixel == marker)
            {
                enforce(cursor < input.length, "Missing MFB RLE count");
                auto count = input[cursor++];
                enforce(count <= output.length-written, "MFB RLE overflow");
                output[written..written+count] = marker;
                written += count;
            }
            else output[written++] = pixel;
        }
        enforce(cursor == input.length, "Unused bytes inside MFB RLE frame");
    }

    const(ubyte)[] frameIndices(size_t index) const
    {
        enforce(index < _frames.length, "MFB frame index out of range");
        return _frames[index];
    }
    const(ubyte)[] trailingData() const { return _trailing; }
    @property {
        short originX() const { return _originX; }
        short originY() const { return _originY; }
        uint spriteSheetWidth() const { return _sheetColumns; }
        uint spriteSheetHeight() const { return _sheetRows; }
        ushort width() const { return _width; }
        ushort height() const { return _height; }
        ushort flags() const { return _flags; }
        ushort numSprites() const { return _count; }
    }
}
