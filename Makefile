# oocat v0.2.0 Makefile
#
# Build, verification gate, test suite, and tri-distribution packaging.
#
# Usage:
#   make build       - compile main.oo to dist/oocat
#   make check       - run oodac check on every .oo file
#   make line-cap    - enforce 16-256 line cap on every .oo and .oot (shim-exempt)
#   make file-law    - reject forbidden file extensions and stray docs
#   make academy     - verify every .oo has the 4-element Academy header
#   make density     - enforce at most 8 pages per directory
#   make verify      - run line-cap, file-law, academy, density, and check
#   make test        - run end-to-end integration and MCP tests
#   make bench       - run performance benchmark suite
#   make package     - build deb, rpm, and arch packages
#   make clean       - remove build artifacts

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oocat

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= 0.2.0

.PHONY: build check line-cap file-law academy density verify clean test bench package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@echo "built $(BIN)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="py js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		$(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== Tier 1: Core CLI Flags, Ranges, Piped Output, and Language Detection ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@./$(BIN) -h > /dev/null && echo "PASS: -h"
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@./$(BIN) -v | grep -q "0.2.0" && echo "PASS: -v"
	@./$(BIN) --help | grep -q -- "-r, --line-range" && echo "PASS: --help documents -r"
	@./$(BIN) --help | grep -q -- "-l, --language" && echo "PASS: --help documents -l"
	@./$(BIN) --help | grep -q -- "-t, --theme" && echo "PASS: --help documents -t"
	@./$(BIN) --help | grep -q -- "--mcp" && echo "PASS: --help documents --mcp"
	@OODA_NO_JAIL=1 ./$(BIN) VERSION --style plain | grep -q "0.2.0" && echo "PASS: file view"
	@OODA_NO_JAIL=1 ./$(BIN) VERSION -n --style plain | grep -q "1" && echo "PASS: line numbers"
	@OODA_NO_JAIL=1 ./$(BIN) main.oo -r 1:5 --style plain | grep -q "oocat Entry Point" && echo "PASS: line range"
	@OODA_NO_JAIL=1 ./$(BIN) main.oo -r1:5 --style plain | grep -q "oocat Entry Point" && echo "PASS: attached short range -r1:5"
	@OODA_NO_JAIL=1 ./$(BIN) VERSION -ljson --style plain | grep -q "0.2.0" && echo "PASS: attached short language -ljson"
	@OODA_NO_JAIL=1 ./$(BIN) VERSION -t1982 --style plain | grep -q "0.2.0" && echo "PASS: attached short theme -t1982"
	@echo "pure capability" | OODA_NO_JAIL=1 ./$(BIN) - --style plain | grep -q "pure capability" && echo "PASS: stdin pipeline"
	@OODA_NO_JAIL=1 ./$(BIN) VERSION -r 50:100 --style plain > /dev/null && echo "PASS: out-of-bounds line range clamping"
	@OODA_NO_JAIL=1 ./$(BIN) VERSION -r -5:1 --style plain | grep -q "0.2.0" && echo "PASS: negative start line clamping"
	@ESC=$$(printf '\033'); ! OODA_NO_JAIL=1 ./$(BIN) VERSION | grep -q "$$ESC" && echo "PASS: non-TTY piped output defaults to uncolored"
	@ESC=$$(printf '\033'); OODA_NO_JAIL=1 ./$(BIN) VERSION --color=always | grep -q "$$ESC" && echo "PASS: non-TTY piped output with --color=always preserves color"
	@OODA_NO_JAIL=1 ./$(BIN) $(BIN) | grep -q "binary file suppressed" && echo "PASS: CLI binary file suppressed"
	@echo "=== Tier 2: MCP Handshake & Protocol Framing ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "2024-11-05" && echo "PASS: MCP initialize protocolVersion"
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q '"name":"oocat","version":"0.2.0"' && echo "PASS: MCP initialize serverInfo"
	@printf '{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP ping"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "view_file" && echo "PASS: MCP tools/list view_file"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "highlight_code" && echo "PASS: MCP tools/list highlight_code"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "list_languages" && echo "PASS: MCP tools/list list_languages"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "slice_lines" && echo "PASS: MCP tools/list slice_lines"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP notifications/initialized produces no response"
	@printf '{"jsonrpc":"2.0","id":4,"method":"shutdown","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":null' && echo "PASS: MCP shutdown"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"exit","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP exit terminates cleanly"
	@test "$$(printf '{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -c '"result":{}')" = "2" && echo "PASS: MCP concatenated JSON-RPC messages without newline"
	@printf '{"jsonrpc":"2.0","id":99,"method":"ping","params":{}}' | ./$(BIN) --mcp | grep -q '"id":99' && echo "PASS: MCP request without trailing newline"
	@(sleep 0.1 && printf '{"jsonrpc":"2.0","id":15,"method":"ping","params":{}}\n') | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP stdio idle pause does not crash server"
	@echo "=== Tier 3: All 4 MCP Tools & Execution Edge Cases ==="
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"VERSION"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "0.2.0" && echo "PASS: MCP view_file basic"
	@printf '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"VERSION"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "total_lines" && echo "PASS: MCP view_file total_lines metadata"
	@printf '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"main.oo","start_line":1,"end_line":5}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "line_count" && echo "PASS: MCP view_file line_count metadata"
	@printf '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"VERSION","highlight":true}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q '\\u001b\[' && echo "PASS: MCP view_file with highlight emits ANSI escapes"
	@printf '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"VERSION","show_line_numbers":false}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "0.2.0" && echo "PASS: MCP view_file without line numbers"
	@printf '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"highlight_code","arguments":{"code":"pub fn hello() -> Int { return 1; }","language":"openooda"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q '\\u001b\[' && echo "PASS: MCP highlight_code explicit language emits ANSI escapes"
	@printf '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"highlight_code","arguments":{"code":"let x: Int = 10;"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q '\\u001b\[' && echo "PASS: MCP highlight_code default language emits ANSI escapes"
	@printf '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"list_languages","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q '\\"py\\"' && echo "PASS: MCP list_languages includes py"
	@printf '{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"slice_lines","arguments":{"content":"alpha\\nbeta\\ngamma\\ndelta","start_line":2,"end_line":3}}}\n' | ./$(BIN) --mcp | grep -q "beta" && echo "PASS: MCP slice_lines pure in-memory slice"
	@printf '{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"slice_lines","arguments":{"content":"one\\ntwo\\nthree","start_line":-5,"end_line":-1}}}\n' | ./$(BIN) --mcp | grep -q "line_count" && echo "PASS: MCP slice_lines negative clamping"
	@printf '{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"oocat_view","arguments":{"path":"VERSION"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "0.2.0" && echo "PASS: MCP oocat_view backward compatibility"
	@printf '{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"oocat_highlight","arguments":{"code":"pub fn test() {}","language":"openooda"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q '\\u001b\[' && echo "PASS: MCP oocat_highlight backward compatibility emits ANSI escapes"
	@echo "=== Tier 4: Negative Trust & Error Responses ==="
	@printf 'invalid json string\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid json exits -32600"
	@printf '{"jsonrpc":"1.0","id":30,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid jsonrpc version exits -32600"
	@printf '{"jsonrpc":"2.0","id":31,"method":"","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP empty method exits -32600"
	@printf '{"jsonrpc":"2.0","id":32,"method":"nonexistent_method","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown method exits -32601"
	@printf '{"jsonrpc":"2.0","id":33,"method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown tool exits -32601"
	@printf '{"jsonrpc":"2.0","id":34,"method":"tools/call","params":{"arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP missing tool name exits -32602"
	@printf '{"jsonrpc":"2.0","id":35,"method":"tools/call","params":{"name":"view_file","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP view_file missing path exits -32602"
	@printf '{"jsonrpc":"2.0","id":36,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"nonexistent_file_xyz.txt"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32000" && echo "PASS: MCP view_file nonexistent file exits -32000"
	@printf '{"jsonrpc":"2.0","id":37,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"$(BIN)"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "binary file suppressed" && echo "PASS: MCP view_file binary file exits -32000"
	@printf '{"jsonrpc":"2.0","id":38,"method":"tools/call","params":{"name":"highlight_code","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP highlight_code missing code exits -32602"
	@printf '{"jsonrpc":"2.0","id":39,"method":"tools/call","params":{"name":"slice_lines","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP slice_lines missing content exits -32602"
	@echo "=== Double-Run Determinism & Response Consistency ==="
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism tools/list Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"VERSION"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"VERSION"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism view_file Run_1 == Run_2"
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"slice_lines","arguments":{"content":"foo\\nbar","start_line":1,"end_line":2}}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"slice_lines","arguments":{"content":"foo\\nbar","start_line":1,"end_line":2}}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism slice_lines Run_1 == Run_2"
	@echo "=== Packaging & Installer Smoke Tests ==="
	@./install.sh --dry-run > /dev/null && echo "PASS: install.sh --dry-run"
	@./install.sh --uninstall --dry-run > /dev/null && echo "PASS: install.sh --uninstall --dry-run"
	@./uninstall.sh --dry-run > /dev/null && echo "PASS: uninstall.sh --dry-run"
	@echo "ALL TESTS PASSED"

bench: $(BIN)
	@echo "=== Running oocat performance benchmarks ==="
	@echo "--- File view benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do OODA_NO_JAIL=1 ./$(BIN) main.oo --style plain > /dev/null; done'
	@echo "--- MCP view_file benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"view_file","arguments":{"path":"main.oo","start_line":1,"end_line":50}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP highlight_code benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"highlight_code","arguments":{"code":"pub fn test() -> Int { return 42; }","language":"openooda"}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP slice_lines benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"slice_lines","arguments":{"content":"line1\\nline2\\nline3\\nline4\\nline5","start_line":2,"end_line":4}}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "--- MCP tools/list benchmark ---"
	@time -p sh -c 'for i in $$(seq 1 100); do printf '\''{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{}}\n'\'' | ./$(BIN) --mcp > /dev/null; done'
	@echo "Benchmark complete."

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oocat
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oocat-uninstall
	@echo "installed oocat and oocat-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oocat $(DESTDIR)$(BINDIR)/oocat-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oocat $(HOME)/.config/oocat; echo "purged user cache and config"; fi
	@echo "uninstalled oocat and oocat-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oocat
	@chmod 0755 dist/deb-root/usr/bin/oocat
	@cp uninstall.sh dist/deb-root/usr/bin/oocat-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oocat-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oocat_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oocat_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oocat-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oocat.spec > ~/rpmbuild/SPECS/oocat.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oocat.spec
	@cp ~/rpmbuild/RPMS/x86_64/oocat-$(VERSION)*.rpm dist/ 2>/dev/null || true
	@if ls dist/oocat-$(VERSION)-1.*.x86_64.rpm 1> /dev/null 2>&1; then cp dist/oocat-$(VERSION)-1.*.x86_64.rpm dist/oocat-$(VERSION)-1.x86_64.rpm; fi
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oocat
	@chmod 0755 dist/arch-pkg/usr/bin/oocat
	@cp uninstall.sh dist/arch-pkg/usr/bin/oocat-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oocat-uninstall
	@printf "pkgname = oocat\npkgbase = oocat\npkgver = $(VERSION)-1\npkgdesc = Sovereign syntax-highlighting file viewer and pager\nurl = https://github.com/openOODA-tools/oocat\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oocat\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oocat-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD dist/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oocat-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cp $(BIN) dist/oocat-linux-x86_64
	@chmod 0755 dist/oocat-linux-x86_64
	@(cd dist && sha256sum oocat-linux-x86_64 > oocat-linux-x86_64.sha256)
	@(cd dist && sha256sum oocat* > checksums.txt)
	@echo "built all packages and generated dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache .blackbox
	@echo "cleaned"
