# K1 5v5 Demo 1.10 发布说明（3v3 基线 + 标定实验场）

- 基线：`F:\K1_5v5_demo_1.9.0`（3v3，含 1.8/1.9 的全部改动）
- 本版本：`F:\K1_5v5_demo_1.10`
- 发布日期：2026-11-03
- 版本定位：**视觉标定工程化** —— 新增离线标定实验场，量化误差并支持真机数据反解；**不改动任何上车参数**
- 适用范围：Booster K1，RoboCup 3v3，头部 d-robotics 544×448

## 1. 相对 1.9.0 的改动

| 类型 | 内容 |
|------|------|
| 新增 | `tools/calib_lab/`：C++ 几何 1:1 移植 + 虚拟标定实验 + CSV 拟合工具 |
| 新增 | `CALIBRATION_1.10.md`：敏感度结论、真机 10 分钟标定流程、验收标准 |
| 新增 | `tools/calib_lab/out/`：本次运行的报告、JSON、合成视图、示例测量 CSV |
| 新增 | `VERSION` = `1.10.0`；三个应用包版本号 → 1.10.0 |
| 未改 | **所有策略/视觉/踢球参数**（与 1.9.0 逐值一致） |

> 为什么不动数值：虚拟实验能证明“参数误差有多贵”，但不能凭空给出真机正确值。
> 现有 `pitch=0.5° / yaw=-0.1°` 是现场经验值，盲改风险大于收益。

## 2. 关键结论（详见 `CALIBRATION_1.10.md`）

- `cy` / `pitch` 是精度瓶颈：2 px 的 `cy` 误差 ≈ 3 m 处 11 cm、5 m 处 31 cm。
- `pitch_compensation` 与 `cy` 不可分辨：必须先棋盘格标内参，再标 pitch/yaw。
- 拟合应以 1~3 m 样本为主：反解后 0.9–3.5 m 残差 1.0~1.3 cm，3.5–6 m 残差 7.9 cm。

## 3. 使用

```bash
# 跑虚拟实验（无需 ROS/CUDA，只需 numpy/Pillow）
python tools/calib_lab/virtual_test.py --config src/vision/config/vision.yaml

# 用真机测量反解补偿
python tools/calib_lab/fit_from_csv.py --config src/vision/config/vision.yaml \
    --head 0.06 0 0.78 0 0.35 0 measurements.csv
```

## 4. 构建与启动（不变）

```bash
cd scripts && chmod +x * && cd ..
./scripts/build.sh
./scripts/start.sh
tail -f vision.log
```

## 5. 校验结果

- 15 个 YAML、21 个 XML 解析通过；11 份 brain 配置与 1.9.0 逐参数一致
- 与 1.9.0 的差异仅限：`VERSION`、3 个 `package.xml`、`CHANGELOG`、`tools/calib_lab/**`、两份文档
- `calib_lab` 自检与 C++ gtest 对齐（误差 < 1e-9）

## 6. 回滚

```powershell
Remove-Item -Recurse -Force F:\K1_5v5_demo_1.10
Copy-Item -Recurse F:\K1_5v5_demo_1.9.0 F:\K1_5v5_demo_1.10
```
