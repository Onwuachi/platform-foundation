require('http')
  .createServer((req, res) => {
    if (req.url === '/ready') return res.end('ready');
    res.end('billings service');
  })
  .listen(3000);
