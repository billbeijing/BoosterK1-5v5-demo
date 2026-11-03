# K1 5v5 Demo 1.8 升级说明

- 基线：`F:\K1_5v5_demo_1.7`（原样保留，未做任何修改）
- 新版本：`F:\K1_5v5_demo_1.8`（目录结构与 1.7 完全一致：363 个文件，逐个校验无缺失）
- 升级日期：2026-11-02 21:18
- 适用范围：Booster K1 人形机器人，RoboCup 5v5，头部 d-robotics 相机（544×448）

> 重要：本次改动全部是**参数与算法层**的调整，**没有在真机/仿真上编译和实测过**（当前环境是 Windows，缺少 ROS2 + CUDA/TensorRT 工具链）。上机前请按第 6 节逐项验证，尤其是大力踢球的力度和远角瞄准。

---

## 1. 本次解决了什么问题

| #   | 问题                                                                                 | 影响                                | 处理                                    |
| --- | ---------------------------------------------------------------------------------- | --------------------------------- | ------------------------------------- |
| 1   | `number_of_players` 还是 3                                                           | 5v5 时队友名额、存活判断、传球决策全按 3 人算        | 改为 5                                  |
| 2   | brain 里相机是 realsense 的 1280×720 / 90°×60°，vision 里是 d-robotics 544×448 / ≈104°×93° | 头部追球角度换算偏差 15%~50%，球永远差一点居中       | 统一为 544×448 / 103.9°×92.9°            |
| 3   | 像素→角度用线性近似                                                                         | 画面 1/4 处角度低估约 25%                 | 改为针孔模型 `atan` 映射                      |
| 4   | `auto_visual_kick_max_direction_error: 1.8 rad`（≈103°）                             | 方向几乎没对准就进 VisualKick，斜着推球         | 收紧到 0.45 rad（≈26°）                    |
| 5   | 射门永远瞄球门中心 y=0                                                                      | 门将站中路时正中下怀                        | 新增远角瞄准（可配 margin / ratio / side / 迟滞） |
| 6   | “大力踢球”只是 `speed_limit=1.4` 写死在 XML 里                                               | 力度不可调，且和普通踢球差别不大                  | 新增 `power_kick` 参数组，速度 1.6、推球 1500 ms |
| 7   | 球的置信度门限 vision 0.4 + brain 60（=0.6）                                                | 3 m 外的球经常被 brain 二次过滤掉            | vision Ball 0.35 + brain 50，放宽远端召回    |
| 8   | 场上只有一个球，却允许多个 Ball 输出                                                              | 重影/远端误检会让决策左右摇摆                   | `single_ball_assumption: true`        |
| 9   | `brain_config/` 下 10 份按机器人（蓝/红 × 1–5 号）的配置仍是旧参数                                    | 现场一旦拷用其中任意一份，5v5 人数、射门瞄准、大力踢球全部回退 | 已把同一套参数同步进 10 份文件                     |
| 10  | `chase.xml` 里 `_while="ball_range<1.0"` 未转义                                        | 该 XML 无法被解析（演示追球树用不了）             | 改为 `&lt;`                             |
| 11  | `demo.xml` 里 `&&` 未转义                                                              | 同样无法被任何标准 XML 解析器读取               | 改为 `&amp;&amp;`                       |

---

## 2. 参数改动明细（旧值 → 新值）

### 2.1 `src/brain/config/config.yaml`

| 参数                                              | 旧值             | 新值                | 说明                                                       |
| ----------------------------------------------- | -------------- | ----------------- | -------------------------------------------------------- |
| `game.number_of_players`                        | 3              | **5**             | 1 门将 + 4 前锋                                              |
| `strategy.ball_confidence_threshold`            | 60.0           | **50.0**          | 与 vision 的 Ball 0.35 组成双重门限，提升远球召回                       |
| `strategy.enable_stable_kick`                   | false          | **true**          | 低威胁时先站稳再出脚，提升出脚方向一致性                                     |
| `strategy.kick_theta_range`                     | 0.2            | **0.15**          | 起脚前球的偏角上限，减少斜踢/踢空                                        |
| `strategy.auto_visual_kick_enable_angle`        | 1.5            | **0.9**           | 球必须在正前方 ±51° 内才允许启动 VisualKick                           |
| `strategy.auto_visual_kick_max_direction_error` | 1.8            | **0.45**          | 未对准期望方向就继续 Adjust                                        |
| `strategy.power_shoot.ymin/ymax`                | ∓0.3           | **∓0.45**         | 允许更靠侧面的球使用大力踢                                            |
| `strategy.power_shoot.speed_limit`              | —（XML 写死 1.4）  | **1.6**           | 与 `robot.vx_limit` 对齐                                    |
| `strategy.power_shoot.min_msec_kick`            | —（XML 写死 1200） | **1500**          | 持续推球时间，球初速更大                                             |
| `strategy.power_shoot.stablize_ms`              | —              | **200**           | 起脚前站稳时间                                                  |
| `strategy.power_shoot.kick_msg_power_near/far`  | 写死 6.0 / 3.0   | **6.0 / 3.0（可配）** | `/kick_ball` 消息的 power 字段                                |
| `strategy.shoot.aim_margin`                     | —              | **0.20**          | 离门柱至少留 0.20 m                                            |
| `strategy.shoot.aim_ratio`                      | —              | **0.55**          | 0=中路，1=最靠边；0.55 表示瞄到 55% 的半门宽处                           |
| `strategy.shoot.aim_side`                       | —              | **"auto"**        | auto 远角 / left / right / center                          |
| `strategy.shoot.aim_hysteresis_y`               | —              | **0.15**          | 球在 ±0.15 m 内保持上一次选边，防抖                                   |
| `vision.cam_pixel_width/height`                 | 1280 / 720     | **544 / 448**     | d-robotics                                               |
| `vision.cam_fov_x/y`                            | 90 / 60        | **105 / 94**      | 与 `brain_config/*.yaml` 的厂商标称值统一；由内参反算约 103.9/92.9，差约 1% |

> 类型提示：`min_msec_kick` / `stablize_ms` 在代码里声明为 `double`，YAML 必须写 `1500.0`、`200.0`，写成整数会触发 rclcpp 参数类型不匹配异常（本版本已按小数写入）。

### 2.2 `src/vision/config/vision.yaml`（`vision_d.yaml` 已同步，`vision_r.yaml` 同步检测段）

| 参数 | 旧值 | 新值 | 说明 |
|------|------|------|------|
| `detection_model.nms_threshold` | 0.4 | **0.45** | 轻微放宽，减少粘连框 |
| `post_process.single_ball_assumption` | false | **true** | 单球取最高置信度 |
| `confidence_thresholds.Ball` | 0.4 | **0.35** | 远端召回 |
| `confidence_thresholds.Opponent` | 0.4 | **0.45** | 减少背景误判成对手 |

### 2.3 其它

- `src/game_controller/launch/launch.py`：**逻辑保持 `enable_ip_white_list: True`**，与现场作业流程和 `scripts/set_gc.sh` 一致；只补充注释说明可改 False 接收任意裁判机。
- `brain_config/blue_*.yaml`、`brain_config/red_*.yaml`（共 10 份）：同步 2.1 的全部调参项；**保留**各自的 `team_id`（蓝 88 / 红 66）、`player_id`、`player_role`（1 号守门员）、`player_start_pos`，以及蓝队 `enable_auto_visual_kick: false` / 红队 `true` 的既有差异。
- `src/brain/behavior_trees/subtrees/subtree_striker_play.xml`：
  - `power_kick` 行增加 `power_kick="true"`，`speed_limit` 1.4→1.6，`min_msec_kick` 1200→1500，`msecs_stablize` 300→200。
  - 普通 `kick` 的 `msecs_stablize` 1000→300（配合 `enable_stable_kick=true`，避免站太久）。
- `src/brain/behavior_trees/chase.xml`：`ball_range<1.0` → `ball_range&lt;1.0`。
- `src/brain/behavior_trees/demo.xml`：`&&` → `&amp;&amp;`。

---

## 3. 代码改动

### 3.1 `brain_tree.cpp` — 头部追球改用针孔模型

```cpp
// 旧：线性近似，画面 1/4 处角度低估约 25%
deltaYaw   = deltaX / camPixX * camAngleX / smoother;
deltaPitch = deltaY / camPixY * camAngleY / smoother;

// 新：atan 映射
focalX = 0.5 * camPixX / tan(camAngleX / 2);
deltaYaw = atan(deltaX / focalX) / smoother;
```

效果：球在画面任意位置都能收敛到中心，视觉踢球起脚时的球心对准更准。

### 3.2 `brain_tree.cpp` — 射门远角瞄准

`CalcKickDir` 不再调用 `directionToOpponentGoal(...)`（固定瞄 y=0），改为：

```
aimY = side * (goalWidth/2 - aim_margin) * aim_ratio
shootDir = directionToTarget(ball.x, ball.y, goalLineX, aimY)
```

- `side` 由 `aim_side` 决定；`auto` 时取球 y 的反侧（远角）。
- 带 0.15 m 迟滞，球在中线附近不会左右跳。
- adult 场（门宽 2.6 m）默认瞄点约 `y = ±0.605 m`，距门柱仍有 0.2 m 余量。

### 3.3 `brain_tree.cpp` / `brain_tree.h` — 可配置的大力踢球

`Kick` 节点新增可选端口 `power_kick`（默认 false）。为 true 时：

```
speed_limit    ← strategy.power_shoot.speed_limit
min_msec_kick  ← strategy.power_shoot.min_msec_kick
stablize_ms    ← strategy.power_shoot.stablize_ms
```

行为树里只要写 `<Kick _while="decision == 'power_kick'" power_kick="true" .../>`，之后调力度只改 `config.yaml`，不用重编或改 XML。

### 3.4 `brain.cpp` — `/kick_ball` 的 power 参数化

原来写死 `dist > 6 ? 3.0 : 6.0`，现在读 `strategy.power_shoot.kick_msg_power_near/far`，默认值保持不变，可在现场按球重/草地阻力统一调整。

---

## 4. 编译与启动（按现场实际脚本）

> 现场工作区目录名通常是 `K1_5v5_Demo_v1.6`（你给的流程）。把 1.8 的内容覆盖进去即可，脚本都用相对路径，不依赖目录名。

```bash
# 1) 进入工作区
cd ~/Workspace/K1_5v5_Demo_v1.6      # 以实际路径为准

# 2) 编译（用仓库自带脚本，等价于 colcon build 全量）
cd scripts
chmod +x *
cd ..
./scripts/build.sh

# 3) 启动（内部会按 vision → brain → game_controller 顺序起）
./scripts/start.sh

# 4) 看日志
tail -f brain.log
tail -f vision.log
tail -f game_controller.log
```

补充说明：

- `scripts/start.sh` 里已经 `source ./install/setup.bash` 并设置 `FASTRTPS_DEFAULT_PROFILES_FILE`，**不需要**再手动 source。
- `scripts/build.sh` 是 `colcon build --parallel-workers $(nproc)`；首次全量编译较慢，之后增量。
- 改 IP 可以用 `./scripts/set_gc.sh`，它会同时改 `brain_config/*.yaml`、`src/brain/config/config.yaml` 和 `game_controller/launch/launch.py` 的白名单，比手改三个地方可靠。
- `brain_tree.cpp` 只改普通 C++ 逻辑，不引入新依赖；行为树是 `BTCPP_format="4"`。

---

## 5. 现场作业流程对照（与你的流程一一对应）

| 你的步骤 | 1.8 对应说明 |
|----------|--------------|
| `ssh-keygen -R 192.168.10.102` | 不变（换机/重装后清指纹） |
| 机器人开机、指示灯变蓝、网线连接 | 不变 |
| 电脑以太网 IP 设为 `192.168.10.X`（非 101/102） | 不变 |
| `ping 192.168.10.102` | 不变 |
| `ssh booster@192.168.10.102` | 不变 |
| 改 `config.yaml` 的 `team_id / player_id / player_role / game_control_ip` | 仍改这一份；**但 5 人上场时建议直接用 `brain_config/blue_X.yaml` / `red_X.yaml`**，里面已按 1–5 号配好 team_id（蓝 88 / 红 66）和角色（1 号守门员）。注意：主模板的 `game_control_ip` 是 `172.169.80.24`，10 份 per-robot 配置是 `192.168.50.217`，现场务必用 `set_gc.sh` 统一成裁判机实际地址 |
| 改 `launch.py` 的 `ip_white_list` | 仍可用；或直接跑 `./scripts/set_gc.sh` 自动改 |
| `sudo nmtui` 连裁判指定 WiFi | 不变。连 WiFi 后网线口仍是 192.168.10.102，SSH 不会断 |
| `cd scripts; chmod +x *; cd ..; ./scripts/build.sh` | 不变 |
| `./scripts/start.sh` | 不变；顺序 vision → brain → game_controller |
| `tail -f brain.log / vision.log / game_controller.log` | 不变 |
| 手柄：RT+A 行走、LT+A 扫场定位、LT+B 比赛、LT+X 接管 | 不变 |

**关于 `brain_config/`**：10 份文件是「按机器人预置」的完整参数集。1.8 已把它们全部同步到新参数，但保留了各自的 team_id / player_id / role，以及蓝队 `enable_auto_visual_kick: false`、红队 `true` 的差异。上哪台机器人就把对应文件拷成 `src/brain/config/config.yaml`（或 `config_local.yaml`，launch 会把 local 覆盖在 main 之上）：

```bash
cp brain_config/blue_3.yaml src/brain/config/config_local.yaml
```

---

## 6. 上机验证清单（按顺序做，别跳）

1. **相机链路**：`ros2 topic echo /boostercamera/head/rgb/camera_info --once`，确认 `width=544, height=448`。
   - 若不是 544×448，说明相机输出被改过：同步改 `vision.yaml` 的 `intrin` 和 `config.yaml` 的 `cam_pixel_*` / `cam_fov_*`。
2. **头部跟踪**：把球放在画面四个角，观察头部是否能把球拉到画面中心附近；若过冲/震荡，把 `brain_tree.cpp` 里的 `smoother=3.5` 调大（4.5~5.0）。
3. **踢球方向**：空门状态下让机器人从不同角度起脚，确认球飞向远角且不出边线；若总打偏同一侧，微调 `strategy.shoot.aim_ratio`（0.55 → 0.45 更保守）。
4. **大力踢球**：先在开阔地测 `power_kick` 的滚动距离，确认不会把球踢出边界；若太猛，把 `speed_limit` 降到 1.4~1.5，或把 `min_msec_kick` 降到 1200。
5. **5 人名额**：同时开 5 台，`ros2 topic echo /robocup/game_controller` 确认 `players_per_team=5`，且每台 `player_id` 不重复。
6. **裁判机连通**：`ros2 topic hz /robocup/game_controller` 应有稳定频率；若没有，确认 `ip_white_list` 是否已改成裁判机 IP（或临时把 `enable_ip_white_list` 设为 False）。

---

## 7. 回滚

1.7 原目录完全未动。任何一步不合适，直接：

```powershell
Remove-Item -Recurse -Force F:\K1_5v5_demo_1.8
Copy-Item -Recurse F:\K1_5v5_demo_1.7\K1_5v5_demo_1.7 F:\K1_5v5_demo_1.8
```

或只回滚某个文件：从 `F:\K1_5v5_demo_1.7\K1_5v5_demo_1.7\...` 拷回对应路径。

---

## 8. 关于“视觉精度要完美”

本次把**能靠参数和几何修正拿到的精度**都做了（FOV 对齐、atan 映射、单球假设、双门限、远角瞄准）。但要说清楚边界：

- **检测模型本身没换。** `best_digua_1223_10.3.engine` 是预编译的 TensorRT 引擎（Orin，TRT 10.3），重训/换模型需要：标注数据 → 训练 YOLOv8 → `scripts/model/gen_wts.py` → `build_engine.sh` 在目标机导出。在 Windows 上无法完成，也不该在没有测试集的情况下盲换。
- **“完美”无法在无真机的情况下承诺。** 上面第 6 节的第 1~4 项必须在场上跑一遍，尤其是 `aim_ratio` 和 `speed_limit`。
- 如果场上仍有远端漏检，按这个顺序加码：
  1. `vision.yaml` 的 `Ball` 阈值 0.35 → 0.30；
  2. `config.yaml` 的 `ball_confidence_threshold` 50 → 45；
  3. 再不行才考虑换模型/加数据。

---

## 9. 改动文件清单

```
src/brain/config/config.yaml
src/brain/src/brain.cpp
src/brain/src/brain_tree.cpp
src/brain/include/brain_tree.h
src/brain/behavior_trees/subtrees/subtree_striker_play.xml
src/brain/behavior_trees/chase.xml
src/brain/behavior_trees/demo.xml
src/vision/config/vision.yaml
src/vision/config/vision_d.yaml
src/vision/config/vision_r.yaml
src/vision/CHANGELOG
src/game_controller/launch/launch.py
brain_config/blue_1.yaml ~ blue_5.yaml
brain_config/red_1.yaml ~ red_5.yaml
```
