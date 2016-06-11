
module math;

public import std.math;

byte sign(T)(T v)
{
	if(v<0) return -1;
	else if(v > 0) return 1;
	else return 0;
}

T saturate(T, T min, T max)(T v)
{
	if(v < min) v = min;
	if(v > max) v = max;

	return v;
}

real norm(V,U)(V[] v, U[] u)
{
	real sum = 0;
	for(size_t i=0; i<v.length; ++i)
	{
		auto t = v[i] - u[i];
		sum += t*t;
	}

	return sqrt(sum) / v.length;
}

real norm(V)(V[] v)
{
	real sum = 0;
	for(size_t i=0; i<v.length; ++i)
	{
		sum += v[i] * v[i];
	}

	return sum;
}

auto sqr(T)(T t)
{
	return t*t;
}

auto closest_power_of_2(T)(T v)
{
	uint est = 1;
	while(v > 1)
	{
		v >>= 1;
		est <<= 1;
	}

	return est;
}

version(unittest)
{
	import des.ts;
}

unittest
{
	assertEq(closest_power_of_2(1), 1);
	assertEq(closest_power_of_2(2), 2);
	assertEq(closest_power_of_2(3), 2);
	assertEq(closest_power_of_2(4), 4);
	assertEq(closest_power_of_2(5), 4);
	assertEq(closest_power_of_2(6), 4);
	assertEq(closest_power_of_2(7), 4);
	assertEq(closest_power_of_2(8), 8);
	assertEq(closest_power_of_2(9), 8);
}
