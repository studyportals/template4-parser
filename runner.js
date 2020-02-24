const fs = require("fs");
const prettier = require("prettier");

function exec(input) {
  return require("./src/template4.js").parse(input);
}

const template4 = fs.readFileSync("test/New.tp4", "utf8");
const reference = fs.readFileSync("test/New.json", "utf8");

let output = JSON.stringify(exec(template4));
output = prettier.format(output, { parser: "json", endOfLine: "crlf" });

if (output.trim() === reference.trim()) {
  console.log("Okay!");
} else {
  console.log("NOT Okay! 🥺");
}
