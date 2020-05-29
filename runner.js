const fs = require("fs");
const prettier = require("prettier");

function exec(input) {
  /**
   * The second argument to "parse()" is the working-directory (cwd) of the
   * Template-engine. This is used as the base to resolve file includes. It
   * should be the folder in which the template being parsed is located. In our
   * current (hard-coded) approach, it is thus "test".
   */
  return require("./src/template4.js").parse(input, "test");
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
output = output.trim().replace(/(?:\\r\\n|\\r|\\n)/g, "\\r\\n");

switch (process.argv[2]) {
  case "output":
    console.log(output);
    process.exit(0);

    break;

  case "test":
    if (output === reference.trim().replace(/(?:\r\n|\r|\n)/g, "\r\n")) {
      console.log("Okay!");
      process.exit(0);
    } else {
      console.log("NOT Okay! 🥺");
      process.exit(1);
    }

    break;
}

process.exit(1);
