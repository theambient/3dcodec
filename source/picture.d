
module picture;

import std.math;

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
