.PHONY: help shell generate mesh-all run-steady run-transient post clean

help:
	@echo "mmh-windnoise — 人頭 風圧場 44 ケース"
	@echo ""
	@echo "  make shell          OpenFOAM コンテナに入る"
	@echo "  make generate       44 ケースディレクトリを生成"
	@echo "  make mesh CASE=...  1 ケースをメッシュ生成"
	@echo "  make run-steady     全ケース simpleFoam（定常・高速）"
	@echo "  make run-transient  全ケース pimpleFoam（10s 非定常）"
	@echo "  make post           ParaView 用 VTK 出力"
	@echo ""
	@echo "例: make mesh CASE=psi000_U010"

shell:
	docker compose run --rm openfoam bash

generate:
	python3 scripts/generate_cases.py

mesh:
	@test -n "$(CASE)" || (echo "Usage: make mesh CASE=psi000_U010" && exit 1)
	docker compose run --rm openfoam bash scripts/mesh_case.sh $(CASE)

run-steady:
	docker compose run --rm openfoam bash scripts/run_matrix.sh simpleFoam

run-transient:
	docker compose run --rm openfoam bash scripts/run_matrix.sh pimpleFoam

post:
	docker compose run --rm openfoam bash scripts/export_vtk.sh

clean:
	rm -rf cases/run/*/processor* cases/run/*/[0-9]* cases/run/*/postProcessing
	find cases/run -name "log.*" -delete
