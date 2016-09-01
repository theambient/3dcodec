
module haar;

import std.math;
import std.stdio;
import des.ts;
import math;

void haar_1d(uint N,I,O)(I[] block, O[] o, uint stride)
{
	const coef = 1.0/SQRT2;
	auto tmp = o.dup;
	foreach(i, x; block)
		tmp[i] = x;

	for(uint n = N; n > 1; n >>= 1)
	{
		uint n2 = n >> 1;

		foreach(k; 0..n2)
		{
			const i = 2 * k * stride;
			const j = (2 * k + 1) * stride;
			const k1 = k * stride;
			const k2 = (n2 + k) * stride;

			o[k1] = coef*(tmp[i] + tmp[j]);
			o[k2] = coef*(tmp[i] - tmp[j]);
		}

		foreach(k;0..n)
			tmp[k*stride] = o[k*stride];
	}
}

void ihaar_1d(uint N,I,O)(const I[] block, O[] o, uint stride)
{
	const coef = 1.0 / SQRT2;
	auto tmp = o.dup;
	foreach(i, x; block)
		tmp[i] = x;

	for(uint n = 2; n <= N; n <<= 1)
	{
		uint n2 = n >> 1;

		foreach(k; 0..n2)
		{
			const i = 2 * k * stride;
			const j = (2 * k + 1) * stride;
			const k1 = k * stride;
			const k2 = (n2 + k) * stride;

			o[i] = coef*(tmp[k1] + tmp[k2]);
			o[j] = coef*(tmp[k1] - tmp[k2]);
		}

		foreach(k;0..n)
			tmp[k*stride] = o[k*stride];
	}
}

void haar_2d(uint N, T)(T[] block)
{
	static auto rec = new real[N*N] ;
	static auto rec2 = new real[N*N];

	// rows
	for(uint i=0; i<N; ++i)
	{
		haar_1d!N(block[i*N ..(i+1)*N], rec[i*N ..(i+1)*N], 1);
	}

	// columns
	for(uint j=0; j<N; ++j)
	{
		haar_1d!N(rec[j..$], rec2[j..$], N);
	}

	for(uint i=0; i<N*N; ++i)
	{
		block[i] = cast(T) rec2[i];
	}
}

void ihaar_2d(uint N, T)(T[] block)
{
	static auto rec = new real[N*N] ;
	static auto rec2 = new real[N*N];

	// rows
	for(uint i=0; i<N; ++i)
	{
		ihaar_1d!N(block[i*N ..(i+1)*N], rec[i*N ..(i+1)*N], 1);
	}

	// columns
	for(uint j=0; j<N; ++j)
	{
		ihaar_1d!N(rec[j..$], rec2[j..$], N);
	}

	for(uint i=0; i<N*N; ++i)
	{
		block[i] = cast(T) rec2[i];
	}
}

unittest
{
	immutable int[] b = [1, 2, 3 , 4];
	real[4] t;
	real[4] r;
	real[4] rec;
	r[] = [5, -2, -1/SQRT2, -1/SQRT2];
	haar_1d!4(b, t, 1U);

	assertEqApprox(t, r, 0.0001);
	ihaar_1d!4(t, rec, 1U);

	assertEqApprox(b, rec, 0.0001);
}

unittest // check Parseval's identity and inversability
{
	import std.random;

	const N = 8;
	const N2 = N*N;

	foreach(i; 0..10)
	{
		real[N2] s, S, rec, tmp;

		foreach(ref v; s)
		{
			v = uniform!short();
		}

		tmp[] = s[];

		haar_2d!N(tmp);
		S[] = tmp[];
		assertEqApprox(norm(S), norm(s), 10e-5);

		ihaar_2d!N(tmp);
		rec[] = tmp[];
		tmp[] = s[] - rec[];
		assertEqApprox(norm(S), norm(rec), 10e-5);
		assertEqApprox(s, rec, 10e-5);
	}
}
