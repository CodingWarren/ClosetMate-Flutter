# ClosetMate Serverless 代理函数

将 API Key 从 APK 中移除，改由服务端持有，保护密钥安全。

## 架构说明

```
Flutter App  ──→  腾讯云 SCF (本函数)  ──→  remove.bg / 百度AI / 和风天气
              (无 API Key)              (API Key 存在服务端环境变量)
```

## 接口列表

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/removebg` | AI 抠图（代理 remove.bg） |
| POST | `/api/baidu/recognize` | 衣物图像识别（代理百度 AI） |
| GET  | `/api/weather?city=北京` | 实时天气（代理和风天气） |

### POST /api/removebg

**请求体（JSON）：**
```json
{ "image_base64": "<图片的 Base64 字符串>" }
```

**成功响应（200）：**
```json
{ "image_base64": "<去背景后 PNG 图片的 Base64 字符串>" }
```

### POST /api/baidu/recognize

**请求体（JSON）：**
```json
{ "image_base64": "<图片的 Base64 字符串>" }
```

**成功响应（200）：** 直接透传百度 AI 原始 JSON 响应。

### GET /api/weather?city=北京

**成功响应（200）：**
```json
{
  "code": "200",
  "city": "北京",
  "now": {
    "temp": "22",
    "feelsLike": "21",
    "text": "晴",
    "icon": "100",
    "windSpeed": "3",
    "humidity": "40"
  }
}
```

---

## 部署步骤（腾讯云 SCF）

### 第一步：创建函数

1. 登录 [腾讯云控制台](https://console.cloud.tencent.com/scf)
2. 进入 **云函数 SCF** → **函数服务** → **新建**
3. 填写：
   - **函数名称**：`closetmate-api-proxy`
   - **运行环境**：`Node.js 18.15`
   - **创建方式**：自定义创建
   - **函数代码**：选择「在线编辑」，将 `index.js` 的内容粘贴进去
4. **执行方法**：`index.main_handler`
5. 点击 **完成**

### 第二步：配置环境变量

在函数详情页 → **函数配置** → **环境变量** → **编辑**，添加以下变量：

| 变量名 | 值 |
|--------|-----|
| `REMOVEBG_API_KEY` | 你的 remove.bg API Key |
| `BAIDU_API_KEY` | 你的百度 AI API Key |
| `BAIDU_SECRET_KEY` | 你的百度 AI Secret Key |
| `QWEATHER_API_KEY` | 你的和风天气 API Key |

### 第三步：创建 API 网关触发器

1. 在函数详情页 → **触发管理** → **创建触发器**
2. 填写：
   - **触发方式**：API 网关
   - **API 服务**：新建 API 服务，名称 `closetmate-proxy`
   - **请求方法**：ANY
   - **发布环境**：发布
   - **鉴权方法**：免鉴权（App 直接调用）
3. 点击 **提交**

### 第四步：获取 API 地址

触发器创建后，在触发管理页面可以看到访问路径，格式如：

```
https://service-xxxxxxxx-xxxxxxxxxx.gz.apigw.tencentcs.com/release
```

复制这个地址（不含末尾斜杠）。

### 第五步：配置 Flutter App

**方式 A（推荐）：** 在 `.env` 文件中填写代理地址：
```
PROXY_BASE_URL=https://service-xxxxxxxx-xxxxxxxxxx.gz.apigw.tencentcs.com/release
```

**方式 B：** 在 App 内 **设置 → AI 服务配置 → 代理服务器** 中填写地址。

---

## 本地测试

可以用 `curl` 快速验证函数是否正常工作：

```bash
# 测试天气接口
curl "https://your-scf-url/release/api/weather?city=上海"

# 测试百度 AI（需要先有一张图片的 base64）
curl -X POST "https://your-scf-url/release/api/baidu/recognize" \
  -H "Content-Type: application/json" \
  -d '{"image_base64":"<base64>"}'
```

---

## 费用说明

腾讯云 SCF 每月有**免费额度**：
- 调用次数：100 万次/月
- 资源使用量：40 万 GBs/月

ClosetMate 的使用量远低于免费额度，**实际费用为零**。

---

## 注意事项

- 函数代码**不包含任何 API Key**，密钥仅存在于 SCF 环境变量中
- 百度 AccessToken 在函数实例内存中缓存，同一实例的多次调用可复用
- remove.bg 接口返回的是二进制 PNG，函数将其转为 Base64 JSON 返回
- SCF API 网关对请求体大小限制为 **6 MB**，图片压缩后的 Base64 约为原图的 1.37 倍，请确保上传图片不超过 4 MB
