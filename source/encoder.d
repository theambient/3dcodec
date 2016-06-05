
module encoder;

import dct;
import picture;
import std.stdio;
import std.exception;

const MB_WIDTH = 16;

class Encoder
{
	public this(string filename, short qp)
	{
		fd = File(filename, "wb");
		this.qp = qp;
	}

	public void encode(Picture pic)
	{
		auto block = new short[MB_WIDTH*MB_WIDTH];
		auto rec = new Picture(pic.width, pic.height);

		foreach(cc; 0..1)
		{
			auto plane = pic.planes[cc];

			for(int by=0; by + MB_WIDTH<=plane.height; by+=MB_WIDTH)
			{
				for(int bx=0; bx + MB_WIDTH<=plane.width; bx+=MB_WIDTH)
				{
					for(int y=0; y<MB_WIDTH; ++y)
					{
						auto idx = (by + y)*plane.width + bx;
						block[MB_WIDTH * y..MB_WIDTH * (y+1)] = plane.pixels[idx..idx + MB_WIDTH];
					}
					dct_2d!MB_WIDTH(block);
					quantize(block, qp);
					idct_2d!MB_WIDTH(block);

					for(int y=0; y<MB_WIDTH; ++y)
					{
						auto idx = (by + y)*plane.width + bx;
						rec.planes[cc].pixels[idx..idx + MB_WIDTH] = block[MB_WIDTH * y..MB_WIDTH * (y+1)];
					}
				}
			}
		}

		print_psnr(pic, rec);
		write_picture(rec);
	}

	public void flush()
	{

	}

	private void quantize(short[] blk, short qp)
	{
		foreach(ref v; blk)
		{
			if(qp > 0)
			{
				v /= qp;
				v *= qp;
			}
			if(v==0) ++cnt;
		}
	}

	private void print_psnr(Picture org, Picture rec)
	{
		real[3] psnr;

		foreach(cc; 0..3)
		{
			psnr[cc] = picture.psnr(org.planes[cc], rec.planes[cc]);
		}

		writefln("psnr: Y: %8.4f U: %8.4f V: %8.4f cnt: %s (%.2f)", psnr[0], psnr[1], psnr[2], cnt, cast(real) cnt / org.planes[0].size);
	}

	private void write_picture(Picture pic)
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

	private File fd;
	int cnt = 0;
	short qp;
}
