.PHONY: help setup generate sync-templates shell mesh run-steady run-transient run-parallel post clean docker-shell

help:
	@echo "mmh-windnoise — 人頭 風圧場 44 ケース"
	@echo ""
	@echo "初回セットアップ (Ubuntu Server 24.04):"
	@echo "  ./scripts/setup-native.sh"
	@echo ""
	@echo "計算:"
	@echo "  make generate       44 ケースディレクトリを生成"
	@echo "  make sync-templates 既存ケースにテンプレート更新を反映"
	@echo "  make mesh CASE=...  1 ケースをメッシュ生成"
	@echo "  make restore-ic CASE=...  初期条件 0/ を復元"
	@echo "  make run-steady     全ケース simpleFoam（定常・高速）"
	@echo "  make run-transient  全ケース pimpleFoam（10s 非定常）"
	@echo "  make run-parallel CASE=... [NP=8]  1ケース MPI 並列"
	@echo "  make post           ParaView 用 VTK 出力"
	@echo ""
	@echo "例: make mesh CASE=psi000_U010"
	@echo ""
	@echo "Docker を使う場合: make docker-shell"

setup:
	./scripts/setup-native.sh

generate:
	python3 scripts/generate_cases.py

sync-templates:
	bash scripts/sync_case_templates.sh

mesh:
	@test -n "$(CASE)" || (echo "Usage: make mesh CASE=psi000_U010" && exit 1)
	bash scripts/mesh_case.sh $(CASE)

restore-ic:
	@test -n "$(CASE)" || (echo "Usage: make restore-ic CASE=psi000_U010" && exit 1)
	bash scripts/restore_case_ic.sh $(CASE)

run-steady:
	bash scripts/run_matrix.sh simpleFoam

run-transient:
	bash scripts/run_matrix.sh pimpleFoam

run-parallel:
	@test -n "$(CASE)" || (echo "Usage: make run-parallel CASE=psi000_U010 NP=8" && exit 1)
	@test -n "$(NP)" || (echo "Usage: NP=8 が必要です（並列2以上）" && exit 1)
	bash scripts/run_case_parallel.sh $(CASE) pimpleFoam $(NP)

run-both:
	@test -n "$(CASE)" || (echo "Usage: make run-both CASE=psi000_U010 NP=8" && exit 1)
	@test -n "$(NP)" || (echo "Usage: NP=8 が必要です（並列2以上）" && exit 1)
	bash scripts/run_case_both.sh $(CASE) $(NP)

post:
	bash scripts/export_vtk.sh

clean:
	rm -rf cases/run/*/processor* cases/run/*/postProcessing
	find cases/run -mindepth 2 -maxdepth 2 -type d -regex '.*/cases/run/[^/]+/[1-9][0-9]*' -exec rm -rf {} + 2>/dev/null || true
	find cases/run -mindepth 2 -maxdepth 2 -type d -regex '.*/cases/run/[^/]+/0\.[0-9]+' -exec rm -rf {} + 2>/dev/null || true
	find cases/run -name "log.*" -delete 2>/dev/null || true

# --- Docker（任意） ---
docker-shell:
	docker compose run --rm openfoam bash

docker-mesh:
	@test -n "$(CASE)" || (echo "Usage: make docker-mesh CASE=psi000_U010" && exit 1)
	docker compose run --rm openfoam bash scripts/mesh_case.sh $(CASE)
