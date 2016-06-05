
module picture;

class Plane
{
	private short[] _pixels;
	private size_t _width;
	private size_t _height;

	this(size_t width, size_t height)
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

	size_t size() @property const
	{
		return _width * _height;
	}

	size_t width() @property const
	{
		return _width;
	}

	size_t height() @property const
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

	this(size_t width, size_t height)
	{
		foreach(cc; 0..3)
		{
			planes[cc] = new Plane(width / scale_x(cc), height / scale_y(cc));
		}
	}

	size_t scale_x(int c)
	{
		return c>0?2:1;
	}

	size_t scale_y(int c)
	{
		return c>0?2:1;
	}
}
