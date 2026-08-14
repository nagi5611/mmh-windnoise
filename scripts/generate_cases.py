#!/usr/bin/env python3
"""44 通りの OpenFOAM ケースディレクトリをテンプレートから生成する。"""

from __future__ import annotations

import math
import shutil
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / "cases" / "template"
RUN_DIR = ROOT / "cases" / "run"
MODEL_SRC = ROOT / "models" / "Super_Average_Head.stl"

YAW_ANGLES = [0, 90, 180, 270]
WIND_SPEEDS = [i * 0.5 for i in range(11)]  # 0.0 .. 5.0


def case_name(yaw_deg: int, speed: float) -> str:
    """ケース名を生成する。"""
    speed_tag = f"{int(round(speed * 10)):03d}"
    return f"psi{yaw_deg:03d}_U{speed_tag}"


def rotate_stl_z(src: Path, dst: Path, yaw_deg: float) -> None:
    """STL を Z 軸周りに回転して書き出す（バイナリ STL）。"""
    angle = math.radians(yaw_deg)
    cos_a = math.cos(angle)
    sin_a = math.sin(angle)

    with src.open("rb") as f:
        header = f.read(80)
        (tri_count,) = struct.unpack("<I", f.read(4))
        triangles: list[tuple[tuple[float, float, float], ...]] = []
        for _ in range(tri_count):
            data = struct.unpack("<12fH", f.read(50))
            normal = data[0:3]
            v1 = data[3:6]
            v2 = data[6:9]
            v3 = data[9:12]
            attr = data[12]
            triangles.append((normal, v1, v2, v3, attr))

    def rot(point: tuple[float, float, float]) -> tuple[float, float, float]:
        x, y, z = point
        return (cos_a * x - sin_a * y, sin_a * x + cos_a * y, z)

    def rot_normal(n: tuple[float, float, float]) -> tuple[float, float, float]:
        x, y, z = n
        return (cos_a * x - sin_a * y, sin_a * x + cos_a * y, z)

    dst.parent.mkdir(parents=True, exist_ok=True)
    with dst.open("wb") as f:
        f.write(header)
        f.write(struct.pack("<I", tri_count))
        for normal, v1, v2, v3, attr in triangles:
            rn = rot_normal(normal)
            rv1 = rot(v1)
            rv2 = rot(v2)
            rv3 = rot(v3)
            f.write(
                struct.pack(
                    "<12fH",
                    *rn,
                    *rv1,
                    *rv2,
                    *rv3,
                    attr,
                )
            )


def patch_file(path: Path, replacements: dict[str, str]) -> None:
    """テキストファイル内のプレースホルダを置換する。"""
    text = path.read_text()
    for key, value in replacements.items():
        text = text.replace(key, value)
    path.write_text(text)


def generate_case(yaw_deg: int, speed: float) -> Path:
    """1 ケースを生成する。"""
    name = case_name(yaw_deg, speed)
    case_dir = RUN_DIR / name

    if case_dir.exists():
        shutil.rmtree(case_dir)
    shutil.copytree(TEMPLATE, case_dir)

    stl_dst = case_dir / "constant" / "triSurface" / "head.stl"
    rotate_stl_z(MODEL_SRC, stl_dst, yaw_deg)

    replacements = {
        "__CASE_NAME__": name,
        "__YAW_DEG__": str(yaw_deg),
        "__U_INF__": f"{speed:.6f}",
        "__U_INF_MAG__": f"{speed:.6f}",
    }

    for rel in [
        "system/controlDict",
        "system/fvSolution",
        "system/snappyHexMeshDict",
        "0/U",
        "README.case",
    ]:
        target = case_dir / rel
        if target.exists():
            patch_file(target, replacements)

    return case_dir


def main() -> None:
  """全 44 ケースを生成する。"""
  if not MODEL_SRC.exists():
    raise FileNotFoundError(f"STL not found: {MODEL_SRC}")

  RUN_DIR.mkdir(parents=True, exist_ok=True)
  cases: list[str] = []

  for yaw in YAW_ANGLES:
    for speed in WIND_SPEEDS:
      case_dir = generate_case(yaw, speed)
      cases.append(case_dir.name)
      print(f"generated: {case_dir.name}  (yaw={yaw}°, U={speed} m/s)")

  manifest = RUN_DIR / "case_manifest.txt"
  manifest.write_text("\n".join(cases) + "\n")
  print(f"\nTotal: {len(cases)} cases -> {manifest}")


if __name__ == "__main__":
  main()
