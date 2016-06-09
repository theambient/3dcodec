
module bm3d;

import picture;
import math;
import std.algorithm;
import std.array;
import std.container.binaryheap;
import std.datetime;
import std.exception;
import std.math;
import std.stdio;
import std.typecons;

/**
	quick one step version of bm3d, though with good qualities.
**/

struct Params
{
	int nHW = 18;
	int N = 8;
	int K = 4;
	int P = 2;
	real sigma = 5.;

	int K2() const @property
	{
		return K * K;
	}
}

struct Point
{
	short x;
	short y;
}

static assert(Point.sizeof == uint.sizeof);

Picture bm3d_run(Picture pic)
{
	auto nom = new real[pic.width * pic.height];
	auto den = new real[pic.width * pic.height];

	nom[] = 0;
	den[] = 0;

	auto filt = new Picture(pic.width, pic.height);

	Params bp;
	auto cols = prepare_idx(pic.width, bp.P);
	auto rows = prepare_idx(pic.height, bp.P);

	StopWatch sw;
	sw.start();
	auto patch_table = build_patch_table(pic, cols, rows, bp);
	sw.stop();
	writefln("build_patch_table time: %s", sw.peek.msecs / 1000.0);

	enforce(sw.peek.msecs == 0);
	foreach(i_r; rows)
	{
		foreach(j_r; cols)
		{
			//writefln("(%s, %s)", i_r, j_r);
			auto k_r = i_r * pic.width + j_r;
			auto patches = patch_table[k_r];

			auto group_3d = build_group_3d(patches, pic, bp);
			rearange_group_3d_fwd(group_3d, bp, patches.length);
			filter_group_3d(group_3d, bp, patches.length);
			rearange_group_3d_inv(group_3d, bp, patches.length);
			register_group_3d(group_3d, bp, nom, den, patches, pic.width);
		}
	}

	foreach(y; rows)
	{
		foreach(x; cols)
		{
			auto idx = y * pic.width + x;
			filt.planes[0][x, y] = cast(short)(nom[idx] / den[idx]);
		}
	}

	return filt;
}

void rearange_group_3d_fwd(ref real[] group_3d, Params bp, size_t npatches)
{
	auto o = new real[group_3d.length];

	foreach(n; 0..npatches)
	{
		foreach(k; 0..bp.K2)
		{
			o[n + k * npatches] = group_3d[n * bp.K2 + k];
		}
	}

	group_3d = o;
}

void rearange_group_3d_inv(ref real[] group_3d, Params bp, size_t npatches)
{
	auto o = new real[group_3d.length];

	foreach(n; 0..npatches)
	{
		foreach(k; 0..bp.K2)
		{
			o[n * bp.K2 + k] = group_3d[n + k * npatches];
		}
	}

	group_3d = o;
}

void filter_group_3d(real[] group_3d, Params bp, size_t npatches)
{
	const T = 2.7 * bp.sigma * npatches;
	auto tmp = new real[npatches];
	auto coef = pow(SQRT1_2, npatches);
	auto coef_norm = 1 / (coef * coef);

	foreach(k; 0..bp.K2)
	{
		auto stride = group_3d[k * npatches..(k + 1) * npatches];
		hadamard(stride, tmp);

		foreach(ref pel; stride)
		{
			if(pel < T)
			{
				pel = 0;
				continue;
			}

			auto v = pel * pel / (pel * pel + bp.sigma * bp.sigma);
			pel *= v;
		}

		hadamard(stride, tmp);

		// normalize
		stride[] *= coef_norm;
	}
}

void register_group_3d(const real[] group_3d, Params bp, real[] nom, real[] den, Point[] patches, uint width)
{
	size_t dn = 0;
	foreach(ppt; patches)
	{
		auto p = group_3d[dn..dn+bp.K2];
		foreach(y; 0..bp.K)
			foreach(x; 0..bp.K)
			{
				auto idx = (ppt.y + y) * width + ppt.x + x;
				nom[idx] += p[y * bp.K + x];
				den[idx] += 1;
			}
	}
}

void hadamard(T)(T[] data, T[] tmp)
{
	if(data.length == 1) return;

	auto l = data.length/2;

	foreach(i; 0..l)
	{
		tmp[i]     = data[i] + data[l+i];
		tmp[l + i] = data[i] - data[l+i];
	}

	data[] = tmp[];

	hadamard(data[0..l], tmp[0..l]);
	hadamard(data[l..$], tmp[l..$]);
}

real[] build_group_3d(Point[] patches, Picture pic, Params bp)
{
	auto group_3d = new real[patches.length * bp.K2];

	size_t dn = 0;
	foreach(ppt; patches)
	{
		auto p = group_3d[dn..dn+bp.K2];
		foreach(y; 0..bp.K)
			foreach(x; 0..bp.K)
				p[y * bp.K + x] = pic.planes[0][ppt.x + x, ppt.y + y];
	}

	return group_3d;
}

Point[][] build_patch_table(Picture pic, short[] cols, short[] rows, Params bp)
{
	auto patch_table = new Point[][pic.width * pic.height];
	auto plane = pic.planes[0];

	foreach(i_r; rows)
	{
		foreach(j_r; cols)
		{
			auto pt = Point(j_r, i_r);
			auto patches = find_patches(plane, bp, pt);
			patch_table[i_r * pic.width + j_r] = patches;
		}
	}

	return patch_table;
}

uint patch_distance(Plane plane, Point pt0, Point pt1, uint K)
{
	auto pixels = plane.pixels;
	uint d = 0;

	uint idx0 = pt0.y * plane.width + pt0.x;
	uint idx1 = pt1.y * plane.width + pt1.x;

	foreach(dy; 0..K)
	{
		foreach(dx; 0..K)
		{
			d += abs(pixels[idx0] - pixels[idx1]);
			++idx0;
			++idx1;
		}

		idx0 += plane.width - K;
		idx1 += plane.width - K;
	}

	return d;
}

Point[] find_patches(Plane pic, Params bp, Point pt)
{
	short xlo = cast(short) max(0, pt.x - bp.nHW);
	short xhi = cast(short) max(pic.width - bp.K, pt.x + bp.nHW + 1);
	short ylo = cast(short) max(0, pt.y - bp.nHW);
	short yhi = cast(short) min(pic.height - bp.K, pt.y + bp.nHW + 1);

	uint threshold = 20 * bp.K2;

	Tuple!(Point,uint)[] table_distance;
	table_distance.length = bp.N + 1;
	auto plane = pic;
	auto pixels = plane.pixels;
	auto heap = heapify!((l, r) => l[1] < r[1])(table_distance, 0);

	foreach(y; ylo..yhi)
	{
		foreach(x; xlo..xhi)
		{
			if(abs(x-pt.x) + abs(y-pt.y) > bp.nHW) continue;
			//if(x == pt.x && y == pt.y) continue;

			auto test_point = Point(x, y);
			auto d = patch_distance(pic, pt, test_point, bp.K);

			if(d < threshold)
			{
				//table_distance ~= tuple(test_point, d);
				heap.insert(tuple(test_point, d));
				if(heap.length > bp.N)
				{
					heap.popFront;
					threshold = heap.front[1];
				}
			}
		}
	}

	table_distance = table_distance[0..min($, bp.N)];

	return map!(x => x[0])(table_distance).array;
}

short[] prepare_idx(uint len, uint P)
{
	short[] idxs;

	for(short i = 0; i<len; i+= P)
	{
		idxs ~= i;
	}

	return idxs;
}

unittest
{
	import std.stdio;

	foreach(deg; 0..4)
	{
		auto len = 1 << deg;
		int[] d;
		int[] tmp;
		foreach(x; 0..len)
			d ~= 0;
		int[] o = d.dup;
		tmp.length = d.length;

		hadamard(d, tmp);
		hadamard(d, tmp);

		foreach(i, v; d)
			assert(v / len == o[i]);
	}
}
