'use strict';

/**
 * ClosetMate API 代理函数
 * 腾讯云 SCF (Serverless Cloud Function) - Node.js 18
 *
 * 路由：
 *   POST /api/removebg        → remove.bg 抠图代理
 *   POST /api/baidu/recognize → 百度 AI 图像识别代理
 *   GET  /api/weather         → 和风天气代理
 *
 * 环境变量（在 SCF 控制台 → 函数配置 → 环境变量 中设置）：
 *   REMOVEBG_API_KEY
 *   BAIDU_API_KEY
 *   BAIDU_SECRET_KEY
 *   QWEATHER_API_KEY
 */

const https = require('https');

// ─── 环境变量 ─────────────────────────────────────────────────────────────────
const REMOVEBG_API_KEY = process.env.REMOVEBG_API_KEY || '';
const BAIDU_API_KEY    = process.env.BAIDU_API_KEY    || '';
const BAIDU_SECRET_KEY = process.env.BAIDU_SECRET_KEY || '';
const QWEATHER_API_KEY = process.env.QWEATHER_API_KEY || '';

// 百度 AccessToken 内存缓存（函数实例生命周期内有效，可跨调用复用）
let _baiduToken        = '';
let _baiduTokenExpiry  = 0;

// ─── 主入口 ───────────────────────────────────────────────────────────────────
exports.main_handler = async (event, context) => {
  // SCF API 网关触发器会在路径前加 /release 或 /test 环境前缀，统一去掉
  const rawPath = event.path || '/';
  const path    = rawPath.replace(/^\/(release|test)/, '');
  const method  = (event.httpMethod || 'GET').toUpperCase();

  const baseHeaders = {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type':                 'application/json; charset=utf-8',
  };

  // 处理 CORS 预检
  if (method === 'OPTIONS') {
    return { statusCode: 200, headers: baseHeaders, body: '' };
  }

  try {
    if (path === '/api/removebg' && method === 'POST') {
      return await handleRemoveBg(event, baseHeaders);
    }
    if (path === '/api/baidu/recognize' && method === 'POST') {
      return await handleBaiduRecognize(event, baseHeaders);
    }
    if (path === '/api/weather' && method === 'GET') {
      return await handleWeather(event, baseHeaders);
    }
    return makeResp(404, { error: 'Not found', path }, baseHeaders);
  } catch (e) {
    console.error('[SCF] Unhandled error:', e);
    return makeResp(500, { error: e.message }, baseHeaders);
  }
};

// ─── Remove.bg 代理 ───────────────────────────────────────────────────────────
async function handleRemoveBg(event, headers) {
  if (!REMOVEBG_API_KEY) {
    return makeResp(500, { error: 'REMOVEBG_API_KEY not configured on server' }, headers);
  }

  const body = parseBody(event);
  const imageBase64 = body.image_base64;
  if (!imageBase64) {
    return makeResp(400, { error: 'Missing required field: image_base64' }, headers);
  }

  const imageBuffer = Buffer.from(imageBase64, 'base64');
  const boundary    = `----ClosetMateBoundary${Date.now()}`;

  // 手动构建 multipart/form-data（无需外部依赖）
  const multipart = buildMultipart(boundary, {
    fields: { size: 'auto' },
    files: [{
      name:        'image_file',
      filename:    'image.png',
      contentType: 'image/png',
      data:        imageBuffer,
    }],
  });

  console.log(`[RemoveBg] Sending ${imageBuffer.length} bytes to remove.bg`);

  const result = await httpsRequest({
    hostname: 'api.remove.bg',
    path:     '/v1.0/removebg',
    method:   'POST',
    headers: {
      'X-Api-Key':      REMOVEBG_API_KEY,
      'Content-Type':   `multipart/form-data; boundary=${boundary}`,
      'Content-Length': multipart.length,
    },
  }, multipart);

  if (result.statusCode !== 200) {
    console.error('[RemoveBg] Error:', result.statusCode, result.body.toString('utf-8').slice(0, 200));
    return makeResp(result.statusCode, {
      error: `remove.bg returned HTTP ${result.statusCode}`,
    }, headers);
  }

  console.log(`[RemoveBg] Success, result size: ${result.body.length} bytes`);
  return makeResp(200, { image_base64: result.body.toString('base64') }, headers);
}

// ─── 百度 AI 识别代理 ─────────────────────────────────────────────────────────
async function handleBaiduRecognize(event, headers) {
  if (!BAIDU_API_KEY || !BAIDU_SECRET_KEY) {
    return makeResp(500, { error: 'Baidu API keys not configured on server' }, headers);
  }

  const body = parseBody(event);
  const imageBase64 = body.image_base64;
  if (!imageBase64) {
    return makeResp(400, { error: 'Missing required field: image_base64' }, headers);
  }

  // 获取 AccessToken（带缓存，避免每次请求都重新鉴权）
  const accessToken = await getBaiduAccessToken();
  if (!accessToken) {
    return makeResp(500, { error: 'Failed to obtain Baidu access token' }, headers);
  }

  // 调用通用物体识别（高级版）接口
  const postBody = `image=${encodeURIComponent(imageBase64)}`;

  console.log(`[BaiduAI] Sending ${imageBase64.length} chars to Baidu AI`);

  const result = await httpsRequest({
    hostname: 'aip.baidubce.com',
    path:     `/rest/2.0/image-classify/v2/advanced_general?access_token=${accessToken}`,
    method:   'POST',
    headers: {
      'Content-Type':   'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(postBody),
    },
  }, postBody);

  if (result.statusCode !== 200) {
    return makeResp(result.statusCode, {
      error: `Baidu AI returned HTTP ${result.statusCode}`,
    }, headers);
  }

  const json = JSON.parse(result.body.toString('utf-8'));
  console.log('[BaiduAI] Response:', JSON.stringify(json).slice(0, 300));
  return makeResp(200, json, headers);
}

// ─── 和风天气代理 ─────────────────────────────────────────────────────────────
async function handleWeather(event, headers) {
  if (!QWEATHER_API_KEY) {
    return makeResp(500, { error: 'QWEATHER_API_KEY not configured on server' }, headers);
  }

  const city = ((event.queryStringParameters || {}).city || '北京').trim();
  console.log(`[QWeather] Looking up city: ${city}`);

  // 1. 查询 Location ID
  const geoResult = await httpsRequest({
    hostname: 'geoapi.qweather.com',
    path:     `/v2/city/lookup?location=${encodeURIComponent(city)}&key=${QWEATHER_API_KEY}`,
    method:   'GET',
    headers:  {},
  });

  if (geoResult.statusCode !== 200) {
    return makeResp(geoResult.statusCode, {
      error: `QWeather geo API returned HTTP ${geoResult.statusCode}`,
    }, headers);
  }

  const geoJson = JSON.parse(geoResult.body.toString('utf-8'));
  if (geoJson.code !== '200' || !geoJson.location || geoJson.location.length === 0) {
    return makeResp(404, { error: `City not found: ${city}`, code: geoJson.code }, headers);
  }

  const locationId = geoJson.location[0].id;
  console.log(`[QWeather] Location ID: ${locationId}`);

  // 2. 查询实时天气
  const weatherResult = await httpsRequest({
    hostname: 'devapi.qweather.com',
    path:     `/v7/weather/now?location=${locationId}&key=${QWEATHER_API_KEY}`,
    method:   'GET',
    headers:  {},
  });

  if (weatherResult.statusCode !== 200) {
    return makeResp(weatherResult.statusCode, {
      error: `QWeather now API returned HTTP ${weatherResult.statusCode}`,
    }, headers);
  }

  const weatherJson = JSON.parse(weatherResult.body.toString('utf-8'));
  if (weatherJson.code !== '200') {
    return makeResp(500, {
      error: `QWeather API error: code=${weatherJson.code}`,
    }, headers);
  }

  return makeResp(200, {
    code: '200',
    city,
    now:  weatherJson.now,
  }, headers);
}

// ─── 百度 AccessToken 获取（带内存缓存）────────────────────────────────────────
async function getBaiduAccessToken() {
  const now = Date.now();
  if (_baiduToken && now < _baiduTokenExpiry) {
    console.log('[BaiduAI] Using cached access token');
    return _baiduToken;
  }

  console.log('[BaiduAI] Fetching new access token...');
  const result = await httpsRequest({
    hostname: 'aip.baidubce.com',
    path:     `/oauth/2.0/token?grant_type=client_credentials&client_id=${BAIDU_API_KEY}&client_secret=${BAIDU_SECRET_KEY}`,
    method:   'POST',
    headers:  { 'Content-Length': 0 },
  });

  if (result.statusCode !== 200) {
    console.error('[BaiduAI] Token fetch failed:', result.statusCode);
    return null;
  }

  const json = JSON.parse(result.body.toString('utf-8'));
  _baiduToken       = json.access_token;
  // 提前 5 分钟过期，避免边界情况
  _baiduTokenExpiry = now + (json.expires_in - 300) * 1000;
  console.log(`[BaiduAI] Token obtained, expires in ${json.expires_in}s`);
  return _baiduToken;
}

// ─── 工具函数 ─────────────────────────────────────────────────────────────────

/** 解析请求体（支持 SCF API 网关的 base64 编码模式） */
function parseBody(event) {
  try {
    let bodyStr = event.body || '{}';
    if (event.isBase64Encoded) {
      bodyStr = Buffer.from(bodyStr, 'base64').toString('utf-8');
    }
    return JSON.parse(bodyStr);
  } catch {
    return {};
  }
}

/** 构造标准 SCF API 网关响应 */
function makeResp(statusCode, data, headers) {
  return {
    statusCode,
    headers,
    body: JSON.stringify(data),
  };
}

/**
 * 发起 HTTPS 请求（纯 Node.js 内置模块，无需 axios）
 * @returns {{ statusCode: number, headers: object, body: Buffer }}
 */
function httpsRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve({
        statusCode: res.statusCode,
        headers:    res.headers,
        body:       Buffer.concat(chunks),
      }));
    });

    req.on('error', reject);

    // 15 秒超时
    req.setTimeout(15000, () => {
      req.destroy(new Error('Request timed out after 15s'));
    });

    if (body) req.write(body);
    req.end();
  });
}

/**
 * 手动构建 multipart/form-data 请求体
 * @param {string} boundary
 * @param {{ fields?: object, files?: Array<{name,filename,contentType,data}> }} parts
 * @returns {Buffer}
 */
function buildMultipart(boundary, { fields = {}, files = [] }) {
  const buffers = [];

  // 普通字段
  for (const [name, value] of Object.entries(fields)) {
    buffers.push(Buffer.from(
      `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="${name}"\r\n` +
      `\r\n` +
      `${value}\r\n`,
    ));
  }

  // 文件字段
  for (const file of files) {
    buffers.push(Buffer.from(
      `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="${file.name}"; filename="${file.filename}"\r\n` +
      `Content-Type: ${file.contentType}\r\n` +
      `\r\n`,
    ));
    buffers.push(file.data);
    buffers.push(Buffer.from('\r\n'));
  }

  // 结束边界
  buffers.push(Buffer.from(`--${boundary}--\r\n`));

  return Buffer.concat(buffers);
}
