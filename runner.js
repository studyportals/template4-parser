var fs = require("fs");

function exec(input) {
  return require("./src/template4.js").parse(input);
}

var template4 = fs.readFileSync("test/New.tp4", "utf8");

console.log(JSON.stringify(exec(template4)));
