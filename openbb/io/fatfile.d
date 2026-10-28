/**
 *	
 */
module openbb.io.fatfile;

import openbb.exceptions;
import std.file;
import std.exception : enforce;

import openbb.common;


private struct Header
{
align(1):
	char[4]	magic;
	uint	numFiles;
}

//! directory entry
private struct Entry
{
	uint offset;
	uint size;
	uint type;
	uint flag;
}

//! ambient audio bank
class FATFile
{
private:
	uint	_numFiles;
	Entry[]	_directory;
	ubyte[]	_data;
public:

	this(string filename)
	{
		_data = cast(ubyte[]) read(filename);
		enforce(_data.length >= 8, "Truncated FAT header");
		
		char[4] magic = cast(char[]) _data[0 .. 4];
		
		if (magic != "0.30")
			throw new IOException("Not a B&B FAT file!");
		
		_numFiles = *cast(uint*) _data[4 .. 8];
		enforce(_numFiles <= (_data.length-8)/Entry.sizeof, "Truncated FAT directory");
		
		_directory = cast(Entry[]) _data[8 .. 8 + _numFiles * Entry.sizeof];
		foreach (entry; _directory)
			enforce(entry.offset >= 8+_numFiles*Entry.sizeof && entry.offset <= _data.length &&
				entry.size <= _data.length-entry.offset, "FAT payload outside file");
	}
	
	const(short)[] opIndex(size_t i)
	in
	{
		assert(i < _numFiles);
	}
	body
	{
		return cast(short[]) _data[_directory[i].offset .. _directory[i].offset + _directory[i].size];
	}
	
@property
{
	uint numFiles()
	{
		return _numFiles;
	}
}
/*
	string toString()
	{
		std.string.format("numFiles: %s\t")
	}
*/
}
