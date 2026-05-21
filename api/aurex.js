const AUREX_API_ORIGIN = 'https://aurex-api-two.vercel.app';
const RETRYABLE_STATUS_CODES = new Set([408, 425, 429, 500, 502, 503, 504]);

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function getPath(req) {
  const rawPath = req.query.path;
  if (Array.isArray(rawPath)) {
    return rawPath.join('/');
  }
  return rawPath || '';
}

function buildUpstreamUrl(req) {
  const url = new URL(`/${getPath(req)}`, AUREX_API_ORIGIN);
  for (const [key, value] of Object.entries(req.query)) {
    if (key === 'path') {
      continue;
    }
    if (Array.isArray(value)) {
      for (const item of value) {
        url.searchParams.append(key, item);
      }
      continue;
    }
    if (value !== undefined) {
      url.searchParams.set(key, value);
    }
  }
  return url;
}

function copyHeader(sourceHeaders, target, key) {
  const value = sourceHeaders.get(key);
  if (value) {
    target.setHeader(key, value);
  }
}

function shouldRetry(status) {
  return RETRYABLE_STATUS_CODES.has(status);
}

module.exports = async function aurexProxy(req, res) {
  if (req.method === 'OPTIONS') {
    res.setHeader('Allow', 'GET, HEAD, OPTIONS');
    res.status(204).end();
    return;
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.setHeader('Allow', 'GET, HEAD, OPTIONS');
    res.status(405).json({ success: false, error: 'Method not allowed' });
    return;
  }

  const upstreamUrl = buildUpstreamUrl(req);
  const isResolve = upstreamUrl.pathname.endsWith('/api/resolve');
  const maxAttempts = isResolve ? 3 : 2;
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      isResolve ? 25000 : 12000,
    );

    try {
      const response = await fetch(upstreamUrl, {
        method: req.method,
        headers: {
          accept: req.headers.accept || 'application/json',
          'user-agent': 'AurexWeb/1.0',
        },
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (shouldRetry(response.status) && attempt < maxAttempts) {
        await response.arrayBuffer().catch(() => null);
        await wait(350 * attempt);
        continue;
      }

      res.status(response.status);
      copyHeader(response.headers, res, 'content-type');
      res.setHeader('Cache-Control', 'no-store, max-age=0');
      res.setHeader('X-Aurex-Proxy-Attempts', String(attempt));

      if (req.method === 'HEAD') {
        res.end();
        return;
      }

      const body = Buffer.from(await response.arrayBuffer());
      res.send(body);
      return;
    } catch (error) {
      clearTimeout(timeout);
      lastError = error;
      if (attempt < maxAttempts) {
        await wait(350 * attempt);
        continue;
      }
    }
  }

  res.status(502).json({
    success: false,
    error: 'Aurex API is temporarily unavailable.',
    detail:
      lastError?.name === 'AbortError' ? 'Upstream timeout' : 'Upstream failure',
  });
};
