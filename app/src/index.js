const http = require("http");
const { add } = require("./math");

const durationBuckets = [0.05, 0.1, 0.2, 0.5, 1, 2];
const requestCounts = new Map();
const requestDurations = new Map();

function encodeLabels(labels) {
  return JSON.stringify(labels);
}

function decodeLabels(key) {
  return JSON.parse(key);
}

function escapeLabelValue(value) {
  return String(value)
    .replace(/\\/g, "\\\\")
    .replace(/\n/g, "\\n")
    .replace(/"/g, '\\"');
}

function formatLabels(labels) {
  return Object.entries(labels)
    .map(([key, value]) => `${key}="${escapeLabelValue(value)}"`)
    .join(",");
}

function observeRequest(labels, durationSeconds) {
  const key = encodeLabels(labels);
  requestCounts.set(key, (requestCounts.get(key) || 0) + 1);

  const stats = requestDurations.get(key) || {
    sum: 0,
    count: 0,
    buckets: durationBuckets.map(() => 0)
  };

  stats.sum += durationSeconds;
  stats.count += 1;

  durationBuckets.forEach((bucket, index) => {
    if (durationSeconds <= bucket) {
      stats.buckets[index] += 1;
    }
  });

  requestDurations.set(key, stats);
}

function renderMetrics() {
  const lines = [
    "# HELP http_requests_total Total number of HTTP requests.",
    "# TYPE http_requests_total counter"
  ];

  for (const [key, count] of requestCounts.entries()) {
    lines.push(`http_requests_total{${formatLabels(decodeLabels(key))}} ${count}`);
  }

  lines.push("# HELP http_request_duration_seconds HTTP request duration in seconds.");
  lines.push("# TYPE http_request_duration_seconds histogram");

  for (const [key, stats] of requestDurations.entries()) {
    const labels = decodeLabels(key);

    durationBuckets.forEach((bucket, index) => {
      lines.push(
        `http_request_duration_seconds_bucket{${formatLabels({
          ...labels,
          le: bucket
        })}} ${stats.buckets[index]}`
      );
    });

    lines.push(
      `http_request_duration_seconds_bucket{${formatLabels({
        ...labels,
        le: "+Inf"
      })}} ${stats.count}`
    );
    lines.push(
      `http_request_duration_seconds_sum{${formatLabels(labels)}} ${stats.sum.toFixed(6)}`
    );
    lines.push(`http_request_duration_seconds_count{${formatLabels(labels)}} ${stats.count}`);
  }

  return `${lines.join("\n")}\n`;
}

function writeJson(res, statusCode, payload) {
  res.writeHead(statusCode, { "Content-Type": "application/json" });
  res.end(JSON.stringify(payload));
}

const server = http.createServer((req, res) => {
  const startedAt = process.hrtime.bigint();
  const method = req.method || "GET";
  const path = new URL(req.url || "/", "http://localhost").pathname;
  let statusCode = 200;

  try {
    if (path === "/metrics") {
      const body = renderMetrics();
      res.writeHead(200, {
        "Content-Type": "text/plain; version=0.0.4; charset=utf-8"
      });
      res.end(body);
      return;
    }

    if (path === "/health") {
      writeJson(res, 200, { status: "healthy" });
      return;
    }

    if (path === "/") {
      writeJson(res, 200, { status: "ok", result: add(2, 3) });
      return;
    }

    statusCode = 404;
    writeJson(res, statusCode, { error: "Not found" });
  } catch (error) {
    statusCode = 500;
    writeJson(res, statusCode, {
      error: "Internal server error",
      message: error instanceof Error ? error.message : "Unknown error"
    });
  } finally {
    const durationSeconds = Number(process.hrtime.bigint() - startedAt) / 1_000_000_000;
    observeRequest(
      {
        method,
        path,
        status: statusCode
      },
      durationSeconds
    );
  }
});

const port = Number(process.env.PORT || 3000);

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
