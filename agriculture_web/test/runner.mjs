#!/usr/bin/env node

import { spawn } from "node:child_process";

const tty = Boolean(process.stdout.isTTY) && !process.env.NO_COLOR && !process.env.CI;
const paint = (code) => (text) => tty ? `\x1b[${code}m${text}\x1b[0m` : String(text);
const c = {
  bold: paint("1"),
  cyan: paint("36"),
  green: paint("32"),
  red: paint("31"),
  yellow: paint("33"),
  gray: paint("90"),
};

const strip = (text) => text.replace(/\x1b\[[0-9;]*m/g, "");
const seconds = (ms) => `${(ms / 1000).toFixed(1)}s`;

function options(argv) {
  const result = { files: [] };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--files") {
      while (argv[i + 1] && !argv[i + 1].startsWith("--")) {
        result.files.push(argv[++i]);
      }
    } else if (argv[i].startsWith("--")) {
      result[argv[i].slice(2)] = argv[i + 1];
      i += 1;
    }
  }
  return result;
}

function runNodeTests(files) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, ["--test", ...files], {
      cwd: process.cwd(),
      shell: false,
      env: process.env,
    });
    let output = "";
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.stderr.on("data", (chunk) => { output += chunk; });
    child.on("error", (error) => resolve({ code: 1, output: `${output}\n${error}` }));
    child.on("close", (code) => resolve({ code: code ?? 1, output }));
  });
}

function parseTests(output) {
  return output.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*(ok|not ok)\s+\d+\s+-\s+(.+?)\s*$/);
    if (!match) return [];
    return [{ status: match[1] === "ok" ? "pass" : "fail", name: match[2] }];
  });
}

function printBox(title, subtitle, filtered) {
  const width = 68;
  const heading = `╭─ ${c.bold(title)} ${"─".repeat(Math.max(1, width - title.length - 4))}╮`;
  console.log();
  console.log(c.cyan(heading));
  const lines = [
    `${c.bold(c.cyan("▶"))} ${c.bold(title)}  ${c.gray("-")}  ${subtitle}`,
    c.gray(`Node test project  ·  ${filtered ? "selected files" : "all tests"}`),
  ];
  for (const line of lines) {
    const plain = strip(line);
    console.log(`${c.cyan("│")}  ${line}${" ".repeat(Math.max(0, width - plain.length - 2))}${c.cyan("│")}`);
  }
  console.log(c.cyan(`╰${"─".repeat(width)}╯`));
}

async function main() {
  const opts = options(process.argv.slice(2));
  if (opts.help || opts.h) {
    console.log("Usage: node test/runner.mjs --title TITLE --subtitle SUBTITLE --files FILE...");
    return;
  }

  const files = opts.files;
  printBox(opts.title || "Web dashboard", opts.subtitle || "Frontend tests", files.length > 0);

  if (files.length === 0) {
    console.log(`\n  ${c.yellow("○ No tests assigned to this member yet.")}\n`);
    return;
  }

  const started = Date.now();
  const result = await runNodeTests(files);
  const tests = parseTests(result.output);
  for (const test of tests) {
    const mark = test.status === "pass" ? c.green("✔") : c.red("✖");
    console.log(`  ${mark} ${test.name}`);
  }

  const passed = tests.filter((test) => test.status === "pass").length;
  const failed = tests.filter((test) => test.status === "fail").length;
  const ok = result.code === 0 && failed === 0;
  if (!ok) console.log(c.red(`\n${result.output.trim()}`));

  const badge = ok ? c.green(" PASS ") : c.red(" FAIL ");
  console.log(`\n  ${badge}  ${c.green(`✔ ${passed} passed`)}  ${failed ? c.red(`✖ ${failed} failed`) : c.gray("✖ 0 failed")}  ${c.gray(`·  ${seconds(Date.now() - started)}`)}\n`);
  process.exitCode = ok ? 0 : 1;
}

main();
