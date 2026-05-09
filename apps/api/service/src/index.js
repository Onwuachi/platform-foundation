const express = require("express");
const { client, httpRequests } = require("./metrics");

const app = express();
const PORT = process.env.PORT || 3000;

app.use((req, res, next) => {
  res.on("finish", () => {
    httpRequests.inc({
      method: req.method,
      route: req.path,
      status: res.statusCode
    });
  });
  next();
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

// Readiness probe
let ready = true;

app.get("/ready", (req, res) => {
  if (!ready) {
    return res.status(503).json({ status: "not_ready" });
  }
  res.status(200).json({ status: "ready" });
});


app.get("/metrics", async (req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});

app.listen(PORT, () => {
  console.log(`API listening on ${PORT}`);
});

const { exec } = require("child_process");

app.post("/deploy/hugo", (req, res) => {
  console.log("🔥 Building Hugo site...");

  exec(`
    docker run --rm \
      -v /opt/hugo/site:/site \
      klakegg/hugo:ext \
      --source /site \
      --destination /site/public \
      --minify
  `, (err, stdout, stderr) => {
    if (err) {
      console.error("❌ Hugo build failed:", stderr);
      return res.status(500).send(stderr);
    }

    console.log("✅ Hugo build complete");

    exec("docker kill -s HUP hugo || true");

    res.send("Hugo rebuilt + nginx reloaded");
  });
});


