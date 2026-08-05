#!/usr/bin/env python3

import tempfile
import types
from pathlib import Path

tod = types.ModuleType("tod")
tod.__dict__["__file__"] = str(Path(__file__).parent / "tod")
exec(Path(tod.__dict__["__file__"]).read_text(), tod.__dict__)

SAMPLE = """# alpha

first project

- [ ] one
- [x] two `wip`

# beta

- [ ] three
"""


def run(command, target, text=""):
    tod.edit(command, target, text)
    return tod.TODO_PATH.read_text()


def main() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tod.TODO_PATH = Path(tmp) / "TODO.md"

        tod.TODO_PATH.write_text(SAMPLE)
        projects = tod.parse_projects(SAMPLE)
        assert [p.name for p in projects] == ["alpha", "beta"]
        assert projects[0].line == 0 and projects[0].desc == "first project"
        assert projects[0].items[0] == {"text": "one", "status": "idle", "line": 4}
        assert projects[0].items[1]["status"] == "done"

        assert "- [ ] one `wip`" in run("active", 4)
        assert "- [x] one `wip`" not in run("done", 4)
        assert "- [x] one" in tod.TODO_PATH.read_text()
        assert "- [ ] one" in run("idle", 4)

        assert "- [ ] four" in run("add", 0, "four")
        assert tod.parse_projects(tod.TODO_PATH.read_text())[0].total == 3

        beta = tod.parse_projects(tod.TODO_PATH.read_text())[1]
        assert "three" not in run("rm", beta.items[0]["line"])

        assert "changed" in run("desc", 0, "changed")
        assert tod.parse_projects(tod.TODO_PATH.read_text())[0].desc == "changed"
        assert "changed" not in run("desc", 0)

        tod.TODO_PATH.write_text(SAMPLE)
        assert run("desc", 7, "beta needs one") == SAMPLE.replace(
            "# beta\n", "# beta\n\nbeta needs one\n"
        )

        # a project with no items gets a blank line before the inserted item
        tod.TODO_PATH.write_text("# gamma\n\nonly a description\n")
        assert run("add", 0, "first") == "# gamma\n\nonly a description\n\n- [ ] first\n"

        for bad in [("done", 0), ("add", 4), ("rm", 99)]:
            try:
                run(*bad)
            except SystemExit:
                continue
            raise AssertionError(f"{bad} should have failed")

    print("ok")


if __name__ == "__main__":
    main()
