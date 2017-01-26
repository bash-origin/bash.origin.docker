
const http = require('http');

const hostname = '0.0.0.0';
const port = process.env.PORT || 8080;

http.createServer(function (req, res) {
    console.log("Request:", req.url);
    res.writeHead(200, {
        'Content-Type': 'text/plain'
    });
    res.end('Hello World from dockerized NodeJS process!');
}).listen(port, hostname, function () {
    console.log(`Server running at http://${hostname}:${port}/`);
});
