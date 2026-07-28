#!/usr/bin/env node
import { tex2typst } from "tex2typst";
import { spawn } from "child_process";
import { readFileSync, writeFileSync } from "fs";

const max_parallel = 16;

// Walk Typst markup tracking escapes and raw spans so that `\$` and dollar
// signs inside backtick runs are never mistaken for math delimiters.
function find_math_spans(src) {
	const spans = [];
	let i = 0;
	while (i < src.length) {
		const c = src[i];
		if (c === "\\") {
			i += 2;
			continue;
		}
		if (c === "`") {
			let n = 0;
			while (src[i + n] === "`") n++;
			const fence = "`".repeat(n);
			const end = src.indexOf(fence, i + n);
			i = end === -1 ? src.length : end + n;
			continue;
		}
		if (c === "$") {
			let j = i + 1;
			while (j < src.length) {
				if (src[j] === "\\") {
					j += 2;
					continue;
				}
				if (src[j] === "$") break;
				j++;
			}
			if (j >= src.length) break;
			spans.push({ start: i, end: j + 1, body: src.slice(i + 1, j) });
			i = j + 1;
			continue;
		}
		i++;
	}
	return spans;
}

function compiles(expr) {
	return new Promise((resolve) => {
		const p = spawn("typst", ["compile", "-", "--format", "pdf", "/dev/null"], {
			stdio: ["pipe", "ignore", "ignore"],
		});
		p.on("error", () => resolve(false));
		p.on("close", (code) => resolve(code === 0));
		p.stdin.on("error", () => {});
		p.stdin.end(`#set page(width: auto, height: auto)\n$${expr}$\n`);
	});
}

async function pooled(items, fn) {
	const out = new Array(items.length);
	let next = 0;
	const workers = Array.from({ length: Math.min(max_parallel, items.length) }, async () => {
		while (true) {
			const i = next++;
			if (i >= items.length) return;
			out[i] = await fn(items[i]);
		}
	});
	await Promise.all(workers);
	return out;
}

function rewrap(body, converted) {
	const display = /^\s/.test(body) && /\s$/.test(body);
	return display ? `$ ${converted} $` : `$${converted}$`;
}

async function repair(src) {
	const spans = find_math_spans(src);
	if (spans.length === 0) return { out: src, fixed: 0, skipped: 0 };

	const ok = await pooled(spans, (s) => compiles(s.body));
	const broken = spans.filter((_, i) => !ok[i]);
	if (broken.length === 0) return { out: src, fixed: 0, skipped: 0 };

	const converted = broken.map((s) => {
		try {
			const t = tex2typst(s.body.trim());
			return t && t.trim() !== "" ? t : null;
		} catch {
			return null;
		}
	});
	const recheck = await pooled(converted, (c) => (c === null ? false : compiles(c)));

	const edits = [];
	let skipped = 0;
	for (let i = 0; i < broken.length; i++) {
		if (recheck[i]) {
			edits.push({ start: broken[i].start, end: broken[i].end, text: rewrap(broken[i].body, converted[i]) });
		} else {
			skipped++;
		}
	}

	let out = src;
	for (let i = edits.length - 1; i >= 0; i--) {
		out = out.slice(0, edits[i].start) + edits[i].text + out.slice(edits[i].end);
	}
	return { out, fixed: edits.length, skipped };
}

function read_stdin() {
	return new Promise((resolve) => {
		let s = "";
		process.stdin.setEncoding("utf8");
		process.stdin.on("data", (d) => (s += d));
		process.stdin.on("end", () => resolve(s));
	});
}

const args = process.argv.slice(2);
const in_place = args.includes("-i");
const quiet = args.includes("-q");
const file = args.find((a) => !a.startsWith("-"));

if (in_place && !file) {
	process.stderr.write("typstfix: -i requires a file argument\n");
	process.exit(2);
}

const src = file ? readFileSync(file, "utf8") : await read_stdin();
const { out, fixed, skipped } = await repair(src);

if (in_place) {
	if (out !== src) writeFileSync(file, out);
} else {
	process.stdout.write(out);
}

if (!quiet && (fixed || skipped)) {
	process.stderr.write(`typstfix: converted ${fixed}, left ${skipped} unfixable\n`);
}
