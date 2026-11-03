# K1 5v5 Demo 1.11 发布说明（3v3 基线 + 移植 main 硬件无关增强）

- 基线：`F:\K1_5v5_demo_1.10`
- 本版本：`F:\K1_5v5_demo_1.11`
- 日期：2026-11-03
- 定位：以旧相机栈为基线的同时，吸收 `BoosterRobotics/robocup_demo`(main) 中**硬件无关**的改进

## 相对 1.10 的改动

| 项 | 说明 |
|----|------|
| 速度死区参数化 | `robot_client.cpp` 里原来写死 `0.3/0.3/0.3`（带 TODO），现改为读 `robot.min_vx/min_vy/min_vtheta`；默认仍 0.3，行为不变 |
| LICENSE | 新增 Apache-2.0（与 robocup_demo-main 一致） |
| .gitignore / .gitattributes | 新增；大文件走 Git LFS，便于发布到 GitHub |
| 其余 | **参数 / 策略 / 行为树 / 相机配置与 1.10 逐项一致**，未改动 |

## 为何只移植这一项

robocup_demo-main 还有 `robot_name` 多机命名空间、仿真(onnx/sim_start)、新相机话题(`/StereoNetNode`)等，
但这些与**另一套话题架构 / 固件**绑定，直接移植会破坏当前 `/boostercamera` 栈。本次只取硬件无关、零风险的速度死区参数化。

## 与 robocup_demo-main 的关系

- 玩法/标定：本分支（1.x）明显更强（power_kick、远角瞄准、calib_lab）。
- 基础设施：main 更新（仿真、多机、onnx、2026 规则）。
- 详见 `F:\K1_5v5_demo_1.11\..\COMPARISON_robocup_demo.md`（对比文档在 workspace，未入包）。

## 构建 / 启动 / 回滚

同 1.10：`./scripts/build.sh` → `./scripts/start.sh`。
回滚：删除本目录，从 1.10 重新拷贝。
