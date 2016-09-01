
module encoder;

import bm3d;
import dct;
import haar;
import math;
import picture;
import std.algorithm;
import std.stdio;
import std.random;
import std.exception;

const MB_WIDTH = 256;

class Encoder
{
	public this(string filename, short qp)
	{
		fd = File(filename, "wb");
		this.qp = qp;
		bm3d_filter = new Bm3dFilter;
	}

	public void encode(Picture pic)
	{
		const N2 = 576/2;

		auto rec = new Picture(pic.width, pic.height);

		foreach(i;0..N2)
		{
			foreach(j;0..N2)
			{
				rec.planes[0][j, i] = pic.planes[0][2*j, 2*i];
				rec.planes[0][j, N2 + i] = cast(short) (0.25 * (pic.planes[0][2*j, 2*i] + pic.planes[0][2*j+1, 2*i] + pic.planes[0][2*j, 2*i+1] + pic.planes[0][2*j+1, 2*i+1]));
			}
		}

		haar_2d!576(pic.planes[0].pixels);
		foreach(i;0..576/2)
		{
			foreach(j;576/2..576)
			{
				pic.planes[0][j, i] = 0;
			}
		}

		pic.planes[0].pixels[576*576/2..$] = 0;

		ihaar_2d!576(pic.planes[0].pixels);

		foreach(i;0..N2)
		{
			foreach(j;0..N2)
			{
				rec.planes[0][N2 + j, i] = pic.planes[0][2*j, 2*i];
			}
		}

		write_picture(rec, fd);
	}

	public void encode2(Picture pic)
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

		//bm3d_filter.filter(pic, rec);
		writef("rec : "); print_psnr(pic, rec);
		write_picture(rec, fd);
	}

	void add_noise(Plane plane, real sigma)
	{
		foreach(ref p; plane.pixels)
		{
			short n = cast(short)((uniform01() - 0.5) * sigma);
			p = cast(short) clip(p + n, 0, 255);
		}
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

	private File fd;
	private Bm3dFilter bm3d_filter;
	int cnt = 0;
	short qp;
}

class Bm3dFilter
{
	public void filter(Picture pic, Picture rec)
	{
		real sigma = 0;
		foreach(i; 0..pic.planes[0].size)
		{
			sigma += abs(rec.planes[0].pixels[i] - pic.planes[0].pixels[i]);
		}

		sigma /= pic.planes[0].size;

		writefln("sigma: %.2f", sigma);
		//rec.planes[0].pixels[] = pic.planes[0].pixels[];
		//add_noise(rec.planes[0], 15);

		Params bp;
		bp.sigma = sigma;

		auto flt = bm3d_run(rec, bp);

		writef("nonf: "); print_psnr(pic, rec);
		writef("filt: "); print_psnr(pic, flt);

		File fd_flt    = File("flt_576x576.yuv", "wb");
		File fd_non_flt = File("non_flt_576x576.yuv", "wb");
		write_picture(flt, fd_flt);
		write_picture(rec, fd_non_flt);

		int block_size = 64;
		real sse = 0;
		auto app_map = calc_rd(pic, rec, flt, block_size, block_size, sse);
		apply_app_map(rec, flt, block_size, block_size, app_map);
	}

	private bool[] calc_rd(Picture pic, Picture rec, Picture flt, int block_width, int block_height, ref real total_sse)
	{
		total_sse = 0;
		auto width = pic.width;
		auto height = pic.height;
		auto width_in_blocks = width / block_width;

		auto map = new bool[width_in_blocks * (height / block_height)];

		foreach(cc; 0..1)
		{
			auto plane = flt.planes[cc];
			int blk_y = 0;

			for(int by=0; by + block_height<=height; by+=block_height, ++blk_y)
			{
				int blk_x = 0;
				for(int bx=0; bx + block_width<=width; bx+=block_width, ++blk_x)
				{
					real sse_rec = 0;
					real sse_flt = 0;
					for(int y=0; y<block_height; ++y)
					{
						for(int x=0; x<block_width; ++x)
						{
							auto idx = (by + y)*width + bx + x;
							sse_rec += sqr(rec.planes[cc].pixels[idx] - pic.planes[cc].pixels[idx]);
							sse_flt += sqr(flt.planes[cc].pixels[idx] - pic.planes[cc].pixels[idx]);
						}
					}

					total_sse += min(sse_rec, sse_flt);
					if(sse_flt < sse_rec)
						map[blk_y * width_in_blocks + blk_x] = true;
				}
			}
		}

		return map;
	}

	private void apply_app_map(Picture rec, Picture flt, int block_width, int block_height, bool[] app_map)
	{
		auto width = rec.width;
		auto height = rec.height;
		auto width_in_blocks = width / block_width;

		assert(app_map.length == width_in_blocks * (height / block_height));

		foreach(cc; 0..1)
		{
			auto plane = flt.planes[cc];
			int blk_y = 0;

			for(int by=0; by + block_height<=height; by+=block_height, ++blk_y)
			{
				int blk_x = 0;
				for(int bx=0; bx + block_width<=width; bx+=block_width, ++blk_x)
				{
					if(app_map[blk_y * width_in_blocks + blk_x])
					{
						for(int y=0; y<block_width; ++y)
						{
							auto idx = (by + y)*plane.width + bx;
							rec.planes[cc].pixels[idx..idx + block_width] = flt.planes[cc].pixels[idx..idx + block_width];
						}
					}
				}
			}
		}
	}
}

void print_psnr(Picture org, Picture rec)
{
	real[3] psnr;

	foreach(cc; 0..3)
	{
		psnr[cc] = picture.psnr(org.planes[cc], rec.planes[cc]);
	}

	writefln("psnr: Y: %8.4f U: %8.4f V: %8.4f", psnr[0], psnr[1], psnr[2]);
}

