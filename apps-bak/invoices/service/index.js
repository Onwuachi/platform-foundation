const PORT = process.env.PORT || 3000;

require('http')
  .createServer((req, res) => {
    if (req.url === '/ready') return res.end('ready');
    res.end('invoices service');
  })
  .listen(PORT);

console.log("invoices running on port " + PORT);
