# C-family conventions (C, C++, CUDA)

Apply together with `general.md`.

- Use tabs for indentation.
- One variable/field definition per line. Never `float x, y, z;`.
- Put spaces around angle brackets: `T <X> value`, not `T<X> value`. This also applies to `template <...>`.
- Put a space after a C-style cast: `(T) x`, not `(T)x`. Example: `(const float2 *) means2d`, not `(const float2 *)means2d`.

```cpp
template <typename T>
T max_value(const std::vector <T> &items)
{
	return *std::max_element(items.begin(), items.end());
}
```

- Opening brace goes on its own new line for functions. No one-liner functions; a function body always goes on its own indented line(s).

```cpp
int square(int x)
{
	return x * x;
}
```

- For function declarations with many arguments, place each argument on its own line and the closing paren on its own line, then the opening brace on the next line:

```cpp
Tensor conv2d(
	const Tensor &input,
	const Tensor &weight,
	int stride,
	int padding
)
{
	return apply_conv(input, weight, stride, padding);
}
```

- For long function calls, put the closing paren on its own line:

```cpp
auto output = conv2d(
	input_batch,
	kernel_weights,
	stride,
	padding
);
```

- For a multi-line array or aggregate initializer, the closing brace goes on its own line (aligned with the statement), not trailing the last element.

```cpp
static const float kernel[3] = {
	0.25f,
	0.50f,
	0.25f
};
```

- For struct/class/enum definitions and inline (in-class) method definitions, the opening brace stays on the same line.

```cpp
struct Point {
	float x;
	float y;

	float norm() const {
		return std::sqrt(x * x + y * y);
	}
};
```

- For control flow (`if`, `for`, `while`, `switch`, etc.) the opening brace stays on the same line. If the entire body is a single line, the braces may be elided.
- Branch chains are K&R style: `} else`, `} else if (...)`, and `} while (...)` sit on the same line as the preceding closing brace.

```cpp
for (int i = 0; i < n; i++) {
	if (values[i] < 0)
		values[i] = 0;
}

if (x > 0) {
	positive(x);
} else if (x < 0) {
	negative(x);
} else {
	zero();
}
```

## CUDA

- Place `__device__` and `__global__` on a separate line before the function declaration.
- `extern "C"` goes on that same separate line, with `__global__`/`__device__`, not on the function declaration.

```cpp
extern "C" __global__
void add_kernel(const float *a, const float *b, float *out, int n)
{
	int i = blockIdx.x * blockDim.x + threadIdx.x;
	if (i < n)
		out[i] = a[i] + b[i];
}
```
