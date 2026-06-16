#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["httpx"]
# ///
import argparse
import datetime
import hashlib
import json
import re
import subprocess
import sys
import unicodedata
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import quote

import httpx

PAPERS = Path.home() / "papers"
STORE = PAPERS / ".store"
INDEX = STORE / "index.json"
INDEX_MD = STORE / "INDEX.md"
REFS = STORE / "references.bib"

ARXIV_ID = re.compile(r"(\d{4}\.\d{4,5})(v\d+)?")
DOI_RE = re.compile(r"10\.\d{4,9}/[-._;()/:A-Za-z0-9]+")
ATOM = "{http://www.w3.org/2005/Atom}"
AX = "{http://arxiv.org/schemas/atom}"
STOP = {"a", "an", "the", "on", "of", "in", "for", "and", "to", "with"}


def fail(msg):
    print(json.dumps({"error": msg}))
    sys.exit(1)


def load_index():
    if INDEX.exists():
        return json.loads(INDEX.read_text())
    return {"papers": {}}


def save_index(idx):
    STORE.mkdir(parents=True, exist_ok=True)
    INDEX.write_text(json.dumps(idx, indent=2, ensure_ascii=False))


def fold(s):
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def slug_title(title):
    s = fold(title).strip()
    s = re.sub(r'[\\/:*?"<>|]+', " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    if len(s) > 150:
        cut = s[:150].rsplit(" ", 1)[0]
        s = cut or s[:150]
    return s or "untitled"


def assign_path(title, current_id, idx):
    base = slug_title(title)
    taken = {p["path"] for pid, p in idx["papers"].items() if pid != current_id and "path" in p}
    name = f"{base}.pdf"
    n = 2
    while name in taken:
        name = f"{base} ({n}).pdf"
        n += 1
    return name


def citekey(authors, year, title, current_id, idx):
    last = "anon"
    if authors:
        last = fold(authors[0]).split()[-1].lower()
        last = re.sub(r"[^a-z0-9]", "", last) or "anon"
    yr = str(year or "nd")
    word = "paper"
    for w in re.findall(r"[A-Za-z0-9]+", fold(title).lower()):
        if w not in STOP:
            word = w
            break
    base = f"{last}{yr}{word}"
    taken = {p.get("citekey") for pid, p in idx["papers"].items() if pid != current_id}
    if base not in taken:
        return base
    for suf in "abcdefghijklmnopqrstuvwxyz":
        if base + suf not in taken:
            return base + suf
    return base + current_id[-4:]


def to_bibtex(rec):
    key = rec["citekey"]
    authors = " and ".join(rec.get("authors") or []) or "Unknown"
    fields = [("title", rec.get("title") or "Untitled"), ("author", authors),
              ("year", str(rec.get("year") or ""))]
    if rec.get("eprint"):
        etype = "misc"
        fields += [("eprint", rec["eprint"]), ("archivePrefix", "arXiv")]
        if rec.get("primary_class"):
            fields.append(("primaryClass", rec["primary_class"]))
        if rec.get("doi"):
            fields.append(("doi", rec["doi"]))
    elif rec.get("doi"):
        etype = "article"
        if rec.get("venue"):
            fields.append(("journal", rec["venue"]))
        fields.append(("doi", rec["doi"]))
    else:
        etype = "misc"
        if rec.get("url"):
            fields.append(("howpublished", rec["url"]))
    body = ",\n".join(f"  {k} = {{{v}}}" for k, v in fields if v)
    return f"@{etype}{{{key},\n{body}\n}}\n"


def http_get(url, **kw):
    return httpx.get(url, follow_redirects=True, timeout=30,
                     headers={"User-Agent": "paper-skill/1.0"}, **kw)


def fetch_arxiv_meta(aid):
    r = http_get(f"http://export.arxiv.org/api/query?id_list={aid}")
    r.raise_for_status()
    root = ET.fromstring(r.text)
    e = root.find(f"{ATOM}entry")
    if e is None or e.find(f"{ATOM}title") is None:
        return None
    title = re.sub(r"\s+", " ", e.findtext(f"{ATOM}title", "").strip())
    authors = [a.findtext(f"{ATOM}name", "").strip() for a in e.findall(f"{ATOM}author")]
    pub = e.findtext(f"{ATOM}published", "")
    year = int(pub[:4]) if pub[:4].isdigit() else None
    doi = e.findtext(f"{AX}doi")
    pc = e.find(f"{AX}primary_category")
    return {"title": title, "authors": [a for a in authors if a], "year": year,
            "doi": doi, "primary_class": pc.get("term") if pc is not None else None}


def fetch_crossref_meta(doi):
    r = http_get(f"https://api.crossref.org/works/{doi}")
    if r.status_code != 200:
        return None
    m = r.json().get("message", {})
    title = (m.get("title") or [""])[0]
    if not title:
        return None
    authors = []
    for a in m.get("author", []):
        nm = " ".join(x for x in [a.get("given"), a.get("family")] if x)
        if nm:
            authors.append(nm)
    parts = (m.get("issued", {}).get("date-parts") or [[None]])[0]
    year = parts[0] if parts and parts[0] else None
    venue = (m.get("container-title") or [""])[0] or None
    return {"title": title, "authors": authors, "year": year, "doi": doi, "venue": venue}


def pdf_title(pdf):
    try:
        out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True, timeout=20).stdout
    except Exception:
        return None
    for line in out.splitlines():
        if line.startswith("Title:"):
            t = line.split(":", 1)[1].strip()
            if t and len(t) > 4:
                return t
    return None


def extract_text(pdf):
    try:
        return subprocess.run(["pdftotext", "-q", str(pdf), "-"],
                              capture_output=True, text=True, timeout=60).stdout
    except Exception:
        return ""


def detect(inp):
    p = Path(inp).expanduser()
    if p.exists() and p.suffix.lower() == ".pdf":
        return "local", str(p)
    if "arxiv.org" in inp:
        m = ARXIV_ID.search(inp)
        if m:
            return "arxiv", m.group(1)
    if re.fullmatch(r"\d{4}\.\d{4,5}(v\d+)?", inp.strip()):
        return "arxiv", ARXIV_ID.search(inp).group(1)
    if inp.startswith("10.") and DOI_RE.match(inp):
        return "doi", inp.strip()
    if "doi.org/" in inp:
        m = DOI_RE.search(inp)
        if m:
            return "doi", m.group(0)
    if inp.startswith("http"):
        return "url", inp
    fail(f"unrecognized input: {inp}")


def acquire(kind, val):
    if kind == "local":
        return Path(val).read_bytes(), None, None
    if kind == "arxiv":
        meta = None
        try:
            meta = fetch_arxiv_meta(val)
        except Exception:
            pass
        r = http_get(f"https://arxiv.org/pdf/{val}.pdf")
        r.raise_for_status()
        if meta:
            meta["eprint"] = val
        return r.content, meta, val
    if kind == "doi":
        meta = fetch_crossref_meta(val)
        link = None
        try:
            j = http_get(f"https://api.crossref.org/works/{val}").json()
            for ln in j.get("message", {}).get("link", []):
                if "pdf" in (ln.get("content-type", "") + ln.get("URL", "")).lower():
                    link = ln["URL"]
                    break
        except Exception:
            pass
        if not link:
            fail(f"DOI {val} has no retrievable PDF; pass a direct PDF URL")
        r = http_get(link)
        r.raise_for_status()
        return r.content, meta, None
    r = http_get(val)
    r.raise_for_status()
    return r.content, {"url": val}, None


def compute_id(kind, val, data):
    if kind == "arxiv":
        return val
    return "sha256:" + hashlib.sha256(data).hexdigest()[:16]


def write_artifacts(rec, text=None):
    STORE.mkdir(parents=True, exist_ok=True)
    if text is not None:
        (STORE / f"{rec['id']}.txt").write_text(text)
    (STORE / f"{rec['id']}.bib").write_text(to_bibtex(rec))


def render():
    STORE.mkdir(parents=True, exist_ok=True)
    idx = load_index()
    rows = sorted(idx["papers"].values(),
                  key=lambda p: (-(p.get("year") or 0), p.get("title", "").lower()))
    lines = ["# Paper catalog", "",
             f"{len(rows)} papers. Generated file — do not edit by hand.", "",
             "| Title | Year | Authors | Tags | Cite | File | Flags |",
             "|---|---|---|---|---|---|---|"]
    for p in rows:
        au = p.get("authors") or []
        who = (au[0] + (" et al." if len(au) > 1 else "")) if au else "—"
        tags = ", ".join(p.get("tags") or []) or "—"
        flags = ", ".join(p.get("flags") or []) or ""
        path = p.get("path", "")
        fname = f"[{path}](<{path}>)" if path else "—"
        title = (p.get("title") or "Untitled").replace("|", "\\|")
        lines.append(f"| {title} | {p.get('year') or '—'} | {who} | {tags} "
                     f"| `{p.get('citekey','')}` | {fname} | {flags} |")
    INDEX_MD.write_text("\n".join(lines) + "\n")
    bibs = []
    for pid in sorted(idx["papers"], key=lambda i: idx["papers"][i].get("citekey", "")):
        f = STORE / f"{pid}.bib"
        if f.exists():
            bibs.append(f.read_text().strip())
    REFS.write_text("\n\n".join(bibs) + ("\n" if bibs else ""))


def ingest(kind, val, idx):
    data, meta, aid = acquire(kind, val)
    if not data.startswith(b"%PDF-"):
        fail("downloaded content is not a valid PDF (bad magic bytes)")
    pid = compute_id(kind, val, data)
    PAPERS.mkdir(parents=True, exist_ok=True)
    STORE.mkdir(parents=True, exist_ok=True)
    tmp = STORE / f"{pid}.tmp.pdf"
    tmp.write_bytes(data)
    text = extract_text(tmp)
    meta = meta or {}
    needs = []
    flags = []

    if not meta.get("doi") and text:
        m = DOI_RE.search(text[:6000])
        if m:
            cm = fetch_crossref_meta(m.group(0))
            if cm:
                meta = {**cm, **{k: v for k, v in meta.items() if v}}

    title = meta.get("title") or pdf_title(tmp)
    if not title:
        title = "Untitled paper"
        needs.append("title")
        flags.append("needs-title")
    if not (meta.get("authors") or meta.get("year") or meta.get("doi")):
        flags.append("unverified-metadata")

    authors = meta.get("authors") or []
    year = meta.get("year")
    dup = [pid2 for pid2, p in idx["papers"].items()
           if pid2 != pid and (
               (meta.get("doi") and p.get("doi") == meta.get("doi")) or
               (p.get("title", "").lower() == title.lower()))]
    if dup:
        flags.append(f"duplicate-of:{dup[0]}")

    rec = idx["papers"].get(pid, {})
    rec.update({
        "id": pid, "title": title, "authors": authors, "year": year,
        "doi": meta.get("doi"), "venue": meta.get("venue"),
        "eprint": meta.get("eprint") or (aid if kind == "arxiv" else None),
        "primary_class": meta.get("primary_class"), "url": meta.get("url"),
        "source": kind, "tags": rec.get("tags", []),
        "added": rec.get("added") or str(datetime.date.today()),
        "flags": flags, "has_digest": rec.get("has_digest", False),
    })
    rec["citekey"] = rec.get("citekey") or citekey(authors, year, title, pid, idx)
    path = assign_path(title, pid, idx)
    final = PAPERS / path
    if final.exists() and rec.get("path") != path:
        final.unlink()
    tmp.rename(final)
    rec["path"] = path
    idx["papers"][pid] = rec
    write_artifacts(rec, text)
    if not rec["tags"]:
        needs.append("tags")
    return rec, needs


def cmd_add(args):
    kind, val = detect(args.input)
    idx = load_index()
    rec, needs = ingest(kind, val, idx)
    save_index(idx)
    render()
    print(json.dumps({"id": rec["id"], "citekey": rec["citekey"], "title": rec["title"],
                      "path": rec["path"], "flags": rec["flags"], "needs": needs}))


def cmd_set(args):
    idx = load_index()
    rec = idx["papers"].get(args.id)
    if not rec:
        fail(f"unknown id: {args.id}")
    if args.title:
        rec["title"] = args.title
        rec["flags"] = [f for f in rec.get("flags", []) if f != "needs-title"]
        new = assign_path(args.title, args.id, idx)
        old = PAPERS / rec.get("path", "")
        dst = PAPERS / new
        if old.exists() and old != dst:
            old.rename(dst)
        rec["path"] = new
    if args.tags is not None:
        rec["tags"] = [t.strip() for t in args.tags.split(",") if t.strip()]
    if args.authors is not None:
        rec["authors"] = [a.strip() for a in args.authors.split(";") if a.strip()]
    if args.year:
        rec["year"] = args.year
    if args.doi:
        rec["doi"] = args.doi
    write_artifacts(rec)
    save_index(idx)
    render()
    print(json.dumps({"id": rec["id"], "citekey": rec["citekey"], "title": rec["title"],
                      "path": rec["path"]}))


def cmd_digest(args):
    idx = load_index()
    rec = idx["papers"].get(args.id)
    if not rec:
        fail(f"unknown id: {args.id}")
    STORE.mkdir(parents=True, exist_ok=True)
    (STORE / f"{args.id}.md").write_text(sys.stdin.read())
    rec["has_digest"] = True
    save_index(idx)
    print(json.dumps({"id": args.id, "digest": str(STORE / f"{args.id}.md")}))


def cmd_search(args):
    url = (f"http://export.arxiv.org/api/query?search_query=all:{quote(args.query)}"
           f"&sortBy={args.sort}&sortOrder=descending&max_results={args.n}")
    r = http_get(url)
    r.raise_for_status()
    root = ET.fromstring(r.text)
    out = []
    for e in root.findall(f"{ATOM}entry"):
        idu = e.findtext(f"{ATOM}id", "")
        m = ARXIV_ID.search(idu)
        if not m:
            continue
        title = re.sub(r"\s+", " ", e.findtext(f"{ATOM}title", "").strip())
        authors = [a.findtext(f"{ATOM}name", "").strip() for a in e.findall(f"{ATOM}author")]
        pub = e.findtext(f"{ATOM}published", "")
        out.append({"arxiv_id": m.group(1), "title": title,
                    "authors": [a for a in authors if a],
                    "year": int(pub[:4]) if pub[:4].isdigit() else None,
                    "published": pub[:10],
                    "in_collection": m.group(1) in load_index()["papers"]})
    print(json.dumps({"query": args.query, "results": out}))


def cmd_render(args):
    render()
    print(json.dumps({"index_md": str(INDEX_MD), "references_bib": str(REFS)}))


def cmd_backfill(args):
    idx = load_index()
    known = {p.get("path") for p in idx["papers"].values()}
    added = []
    for pdf in sorted(PAPERS.glob("*.pdf")):
        if pdf.name in known:
            continue
        data = pdf.read_bytes()
        pid = "sha256:" + hashlib.sha256(data).hexdigest()[:16]
        if pid in idx["papers"]:
            continue
        title = pdf_title(pdf) or pdf.stem
        text = extract_text(pdf)
        meta = {"title": title, "authors": [], "year": None}
        if text:
            m = DOI_RE.search(text[:6000])
            if m:
                cm = fetch_crossref_meta(m.group(0))
                if cm:
                    meta = cm
        flags = ["backfilled"]
        if not (meta.get("authors") or meta.get("year")):
            flags.append("unverified-metadata")
        rec = {"id": pid, "title": meta["title"], "authors": meta.get("authors") or [],
               "year": meta.get("year"), "doi": meta.get("doi"), "venue": meta.get("venue"),
               "source": "backfill", "tags": [], "added": str(datetime.date.today()),
               "flags": flags, "has_digest": False, "path": pdf.name}
        rec["citekey"] = citekey(rec["authors"], rec["year"], rec["title"], pid, idx)
        idx["papers"][pid] = rec
        write_artifacts(rec, text)
        added.append({"id": pid, "title": rec["title"], "flags": flags})
    save_index(idx)
    render()
    print(json.dumps({"added": added, "count": len(added)}))


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("add"); a.add_argument("input"); a.set_defaults(fn=cmd_add)
    s = sub.add_parser("set"); s.add_argument("id")
    s.add_argument("--title"); s.add_argument("--tags"); s.add_argument("--authors")
    s.add_argument("--year", type=int); s.add_argument("--doi"); s.set_defaults(fn=cmd_set)
    d = sub.add_parser("digest"); d.add_argument("id"); d.set_defaults(fn=cmd_digest)
    sr = sub.add_parser("search"); sr.add_argument("query")
    sr.add_argument("-n", type=int, default=5)
    sr.add_argument("--sort", default="submittedDate",
                    choices=["submittedDate", "relevance", "lastUpdatedDate"])
    sr.set_defaults(fn=cmd_search)
    r = sub.add_parser("render"); r.set_defaults(fn=cmd_render)
    b = sub.add_parser("backfill"); b.set_defaults(fn=cmd_backfill)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
