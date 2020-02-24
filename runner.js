const fs = require("fs");
const prettier = require("prettier");

function exec(input) {
  return require("./src/template4.js").parse(input, "test/");
}

const template4 = fs.readFileSync("test/New.tp4", "utf8");
const reference = fs.readFileSync("test/New.json", "utf8");

let output = "";

try {
  output = JSON.stringify(exec(template4));
} catch (e) {
  console.log(`${e.name}: ${e.message}`);
}
output = prettier.format(output, { parser: "json", endOfLine: "crlf" });

switch (process.argv[2]) {
  case "output":
    console.log(output);
    process.exit(0);

    break;

  case "test":
    if (output.trim() === reference.trim()) {
      console.log("Okay!");
      process.exit(0);
    } else {
      console.log("NOT Okay! 🥺");
      process.exit(1);
    }

    break;
}

process.exit(1);
