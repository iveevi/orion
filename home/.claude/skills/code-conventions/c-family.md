# C-family conventions (C, C++, CUDA, WGSL, Slang)

Apply together with `general.md`.

- Use tabs for indentation.
- Never exceed 3 levels of indentation in a function body. If a fourth is needed, the code wants extracting into a helper, an early `return`/`continue` to flatten a branch, or an inverted guard clause. Deep nesting is a signal the function is doing too much, not a formatting detail.
- One variable/field definition per line. Never `float x, y, z;`.
- Put spaces around angle brackets: `T <X> value`, not `T<X> value`. This also applies to `template <...>`. Does not apply to Slang: write `bounce<S, M>(thread)` there.
- Put a space after a C-style cast: `(T) x`, not `(T)x`. Example: `(const float2 *) means2d`, not `(const float2 *)means2d`.
- Never use anonymous namespaces or `detail` namespaces.
- Avoid `static` on free functions. Only add it when there is a genuine name conflict across translation units.
- Prefer `auto` over long type names when the type is clear from the initializer. Keep the const-ness and pointer/reference-ness explicit: `auto *`, `const auto &`, `const auto *`. Short built-in types (`char`, `size_t`, `bool`) stay spelled out.
- Use fixed-width `<cstdint>` types for concretely-sized integers. Never use bare `int`, `unsigned`, `long`, `short` as a variable/field/parameter/return type: write `int32_t`, `uint32_t`, `int64_t`, `uint8_t`, etc. Exceptions: `int` in `main`'s signature (the standard mandates it), and `char`/`size_t`/`bool` which stay as-is. For `<cctype>` casts prefer `(uint8_t) c` over `(unsigned char) c`.

```cpp
auto *function = llvm::Function::Create(signature, linkage, name, target);
const auto &operation = expression.node.as <BinaryOperation> ();
auto tokens = tokenize(source);
size_t index = 0;
```

- Avoid declaration-style initialization `T x(...)` and `T x;`. Always prefer `auto x = T(...)`, which reads like a `let` binding. This includes default construction: `auto x = T()`.
- Declare and define functions and methods with a trailing return type: `auto name(...) -> T`. The exception is `void`-returning functions, which keep the leading `void`.

```cpp
auto tokenize(const std::string &source) -> std::vector <Token>;
auto Parser::peek() const -> const Token &
{
	return tokens[index];
}

void resolve_symbols(const Module &module);
```

```cpp
auto builder = llvm::IRBuilder <> (context);
auto input = std::ifstream(path);
auto context = llvm::LLVMContext();
auto module = Module();
```
- Never use exceptions. No `throw`, no `try`/`catch`. Report the error and terminate, or return a status/optional.
- For a `vswitch`/`vcase`, always wrap each case body in `{ ... }` with a blank line before and after each case. For a plain `switch`, use that same braced-and-spaced form only when at least one case body spans multiple lines or declares locals; otherwise write compact one-liner cases with no braces and no blank lines. For grouped fallthrough labels, stack the labels on their own lines above the shared body. The `default:` case may always be a one-liner without braces.

```cpp
switch (kind) {
case Kind::Add:
	return apply_add();
case Kind::Sub:
case Kind::Neg:
	return apply_sub();
default:
	return apply_fallback();
}

switch (node) {

case Kind::Let: {
	auto value = evaluate();
	bind(value);
	break;
}

default:
	report();
}
```

- Prefer constructor syntax `T(...)` for initialization, with no space before the paren. C++20 parenthesized aggregate initialization means this works for aggregates too.
- When a braced initializer list is required, put a space between the type and the brace: `T { ... }`, never `T{...}`.

```cpp
tokens.push_back(Token(Identifier(text), start, index));
Point point = Point(1.0f, 2.0f);
std::vector <int> values = { 1, 2, 3 };
```
- Use `fmt` for all output and formatting. Never use stdio (`printf`) or iostreams (`std::cout`, `std::cerr`).

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

- Initialize structs with designated initializers, naming every field: `{ .x = 1.0f, .y = 2.0f }`. Never positional. C++ forbids mixing the two forms and requires declaration order.

```cpp
auto point = Point { .x = 1.0f, .y = 2.0f };

static const Entry table[] = {
	{ .kind = Kind::Colon, .text = ":" },
	{ .kind = Kind::Comma, .text = "," }
};
```

- Name the type in a returned initializer rather than relying on the deduced braced form: `return Power { .left = 1, .right = 2 };`, not `return { 1, 2 };`.

- When a designated initializer does not comfortably fit on one line, put each field on its own line with the closing brace on its own line. Braces around a single-statement branch are required once its body spans multiple lines.

```cpp
	if (text == entry.text) {
		return Token {
			.kind = entry.kind,
			.offset = start,
			.length = length
		};
	}
```

- For struct/class/enum definitions and inline (in-class) method definitions, the opening brace stays on the same line.
- Unless specifically requested, do not inline method definitions inside the class declaration. Declare methods in the class, define them out-of-class (with the opening brace on its own line, like any other function).

```cpp
struct Point {
	float x;
	float y;

	float norm() const;
};

float Point::norm() const
{
	return std::sqrt(x * x + y * y);
}
```

- For control flow (`if`, `for`, `while`, `switch`, etc.) the opening brace stays on the same line. If the entire body is a single line, the braces may be elided.
- Branch chains are K&R style: `} else`, `} else if (...)`, and `} while (...)` sit on the same line as the preceding closing brace.
- Keep a blank line before and after a control flow block, separating it from surrounding statements. The exception is the branches of one `if`/`else if`/`else` chain, which stay together with no blank lines between them. No blank line is needed directly after the enclosing `{` or directly before the enclosing `}`.

```cpp
int total = compute_total(values);

if (total > limit) {
	report_overflow(total);
} else {
	accept(total);
}

return total;
```

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

## WGSL

- Apply the formatting rules above (tabs, function brace on its own line, control-flow brace on the same line).
- Place stage attributes (`@vertex`, `@fragment`, `@compute`) on a separate line before the function declaration, like CUDA's `__global__`.

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
