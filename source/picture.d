
module picture;

import std.math;
import std.stdio;

class Plane
{
	private short[] _pixels;
	private uint _width;
	private uint _height;

	this(uint width, uint height)
	{
		_width = width;
		_height = height;
		_pixels = new short[width * height];
	}

	ref short opIndex(size_t x, size_t y)
	{
		return _pixels[y * _width + x];
	}

	short opIndex(size_t x, size_t y) const
	{
		return _pixels[y * _width + x];
	}

	uint size() @property const
	{
		return _width * _height;
	}

	uint width() @property const
	{
		return _width;
	}

	uint height() @property const
	{
		return _height;
	}

	short[] pixels() @property
	{
		return _pixels;
	}
}

class Picture
{
	Plane[3] planes; // YUV

	uint dts;
	uint pts;

	this(uint width, uint height)
	{
		foreach(cc; 0..3)
		{
			planes[cc] = new Plane(width / scale_x(cc), height / scale_y(cc));
		}
	}

	uint scale_x(int c)
	{
		return c>0?2:1;
	}

	uint scale_y(int c)
	{
		return c>0?2:1;
	}

	uint width() @property const
	{
		return planes[0].width;
	}

	uint height() @property const
	{
		return planes[0].height;
	}
}

real psnr(Plane l, Plane r)
{
	real mse = 0;
	foreach(k; 0..l.size)
	{
		auto v = l.pixels[k] - r.pixels[k];
		mse += v*v;
	}
	mse /= l.size;

	return 10 * log10(255*255/mse);
}

auto clip(T)(T v, T lo, T hi)
{
	if(v < lo) v = lo;
	else if (v > hi) v = hi;

	return v;
}

void write_picture(Picture pic, File fd)
{
	auto buf = new ubyte[pic.planes[0].size];
	foreach(cc; 0..3)
	{
		auto plane = pic.planes[cc];
		auto plane_buf = buf[0..plane.size];
		foreach(k;0..plane.size)
		{
			plane_buf[k] = cast(ubyte) plane.pixels[k];
		}
		fd.rawWrite(plane_buf);
	}
}
