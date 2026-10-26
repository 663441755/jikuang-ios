# 机况 · Jikuang

iPhone 硬件状态监控 App 的 iOS 原生实现（SwiftUI）。

原型视觉稿：[`机况-原型.html`](机况-原型.html)

---

## 一、这是什么

机型信息、CPU 负载、内存、存储、实时网速、机身温度估算、充电功率估算、13 项硬件自检。

所有数据本机读取，不上传、无账号、无广告。

---

## 二、环境要求

| 项 | 要求 |
|---|---|
| 编译 | macOS + Xcode（本机 Windows 无法编译，用 GitHub Actions 云编译） |
| 运行 | iOS 17.0 及以上 |
| 装机 | Sideloadly 或 AltStore + 一个 Apple ID（免费账号即可） |

---

## 三、三步拿到 IPA

### 第 1 步：把代码推到 GitHub

在 GitHub 新建一个仓库（建议 **Public**，Actions 免费无限次；Private 是每月 200 分钟 macOS 额度，也够用十来次）。

然后在项目目录执行（把 `你的用户名` 和 `仓库名` 换掉）：

```bash
git add .
git commit -m "init: 机况 iOS 工程"
git branch -M main
git remote add origin https://github.com/你的用户名/仓库名.git
git push -u origin main
```

### 第 2 步：等云端编译

推送完成后打开仓库页面的 **Actions** 标签页，会看到 `Build IPA` 正在跑。

大约 5～8 分钟跑完，页面底部 **Artifacts** 里下载 `Jikuang-ipa`，解压得到 `Jikuang.ipa`。

> 如果显示失败，点进失败的 job 看日志，把红色报错那段发我。

### 第 3 步：装到 iPhone

1. Windows 下载 **Sideloadly**（sideloadly.io）
2. iPhone 用数据线连电脑
3. 把 `Jikuang.ipa` 拖进 Sideloadly
4. Apple ID 填你的（会用来签名，密码只走 Apple 官方接口）
5. 点 Start，等它跑完
6. iPhone 上：**设置 → 通用 → VPN与设备管理 → 信任你的开发者证书**
7. 打开「机况」

> 免费 Apple ID 签名的 App **7 天后失效**，重连电脑在 Sideloadly 里点一下重新签名即可，3 分钟。想签 1 年就买 $99 开发者账号。

---

## 四、工程结构

```
project.yml                        XcodeGen 工程定义（改配置改这里）
.github/workflows/build-ipa.yml    GitHub Actions 云编译
Jikuang/
├── JikuangApp.swift               入口
├── Theme.swift                    配色 / 卡片样式
├── Core/
│   ├── SystemMetrics.swift        CPU / 内存 / 存储 / 网络 / 电池 / 温度估算
│   ├── ChargeEstimator.swift      充电功率估算 + 会话记录
│   ├── DetectEngine.swift         13 项硬件自检
│   └── DeviceInfo.swift           机型映射、灵动岛判断
├── Components/Charts.swift        波形图 / 环形表 / 半环表 / 统计块
└── Views/
    ├── RootView.swift             底部 Tab
    ├── OverviewView.swift         概览
    ├── ChargeView.swift           充电
    ├── MonitorView.swift          监控（灵动岛预览）
    ├── WidgetPreviewView.swift    小组件预览
    ├── ToolsView.swift            工具（设备检测在「实用」分组第一个）
    └── DetectView.swift           设备检测页
```

---

## 五、数据真实性说明

| 指标 | 数据来源 | 准确度 |
|---|---|---|
| CPU 负载 | `host_processor_info` 内核 tick 差分 | 真实 |
| 内存 | `host_statistics64` | 真实 |
| 存储 | `FileManager` 卷容量 | 真实 |
| 网速 | `getifaddrs` 字节计数差分 | 真实 |
| 电量 / 充电状态 | `UIDevice` | 真实 |
| 机身温度 | 一阶热模型（负载积分 + 热惯性 + 系统 thermalState 修正） | **估算**，误差 ±2℃ |
| 充电功率 | ΔSoC × 电池 Wh ÷ 时间 ÷ 链路效率 | **估算**，误差 ±1.5W |

iOS 不开放温度与充电功率的读数接口，这两项只能推算——App Store 上同类产品（Device Kit、WattWave）都是同样做法，并且必须在界面上标注为估算值。

---

## 六、当前版本已知边界

- **灵动岛**：MonitorView 里是 App 内预览。真正上岛需要单独的 Widget Extension 目标，第二版加。
- **小组件**：目前是设计稿实景预览，未接 WidgetKit 数据源。
- **工具**：工具网格里除「手电筒」和「设备检测」外，其余为占位，点击提示下一版接入。
- **电池健康度/循环次数**：iOS 无公开 API，任何 App 都拿不到，未列入检测项。
