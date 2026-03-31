const PORT = process.env.PORT || 3000;

require('http')
  .createServer((req, res) => {
    if (req.url === '/ready') return res.end('ready');
    res.end('derrick-app service');
  })
  .listen(PORT);

console.log("derrick-app running on port " + PORT);
