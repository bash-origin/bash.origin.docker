
console.log("Starting server:", __filename);

const http = require('http');
const path = require("path");
const fs = require("fs");

const hostname = '0.0.0.0';
const port = process.env.PORT || 8080;

http.createServer(function (req, res) {
    console.log("Request:", req.url);
    res.writeHead(200, {
        'Content-Type': 'text/plain'
    });
    res.end('Hello World from dockerized NodeJS process [' + fs.readFileSync(path.join(__dirname, "file.txt"), "utf8") + ']!');
}).listen(port, hostname, function () {
    console.log(`Server running at http://${hostname}:${port}/`);
});