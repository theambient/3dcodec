
import darg;
import encoder;
import picture;
import std.conv;
import std.exception;
import std.regex;
import std.stdio;

struct Options
{
	@Option("help", "h")
	@Help("Prints this help.")
	OptionFlag help;

	@Option("frames", "f")
	@Help("Number of frames to encode.")
	size_t frames_to_decode = size_t.max;

	@Option("qp", "q")
	@Help("Quantization parameter.")
	short qp = 24;

	@Argument("<input-file>")
	@Help("Input file")
	string input_file;

	@Argument("<output-file>")
	@Help("Output file")
	string output_file;
}

// YUV 420
class YuvFileReader
{
	this(string input_file, int w, int h)
	{
		this.input_file = input_file;
		this.width = w;
		this.height = h;

		buf = new ubyte[w*h];
		fd = File(input_file, "rb");
	}

	Picture read()
	{
		auto p = new Picture(width, height);
		foreach(cc; 0..3)
		{
			auto buf_slice = buf[0..p.planes[cc].size];
			auto r = fd.rawRead(buf_slice);
			enforce(r.length == buf_slice.length, "failed to read full frame");
			foreach(k;0..r.length)
				p.planes[cc].pixels[k] = r[k];
		}

		return p;
	}

	private string input_file;
	private int width;
	private int height;
	private File fd;
	private ubyte[] buf;
}

class App
{
	void run(string[] args)
	{
		auto options = parseArgs!Options(args[1..$]);

		int w,h;
		parse_width_height(options.input_file, w, h);
		auto reader = new YuvFileReader(options.input_file, w,h);
		auto encoder = new Encoder(options.output_file, options.qp);

		int cnt = 0;
		for(Picture pic = reader.read(); pic !is null && cnt < options.frames_to_decode; pic = reader.read())
		{
			encoder.encode(pic);
			++cnt;
			if(cnt == options.frames_to_decode) break; // to avoid one extra frame reading
		}

		encoder.flush();

		writefln("encoded %d pictures", cnt);
	}

	void parse_width_height(string s, ref int w, ref int h)
	{
		auto r = regex(r"(\d+)x(\d+)+");
		auto c = matchFirst(s, r);
		enforce(c, "failed to deduce video size from filename (using WxH entry)");
		w = to!int(c[1]);
		h = to!int(c[2]);
	}
}

int main(string[] args)
{
	immutable usage = usageString!Options("example");
	immutable help = helpString!Options;

	try
	{
		auto app = new App;
		app.run(args);
		return 0;
	}
	catch (ArgParseError e)
	{
		writeln(e.msg);
		writeln(usage);
		return 1;
	}
	catch (ArgParseHelp e)
	{
		// Help was requested
		writeln(usage);
		write(help);
		return 0;
	}
}
