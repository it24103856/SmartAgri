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

const seconds = (ms) => `${(ms / 1000).toFixed(1)}s`;
const strip = (text) => text.replace(/\x1b\[[0-9;]*m/g, "");

function box(lines, color = c.cyan, title = "") {
  const width = 64;
  const heading = title
    ? `╭─ ${c.bold(title)} ${"─".repeat(Math.max(1, width - title.length - 4))}╮`
    : `╭${"─".repeat(width)}╮`;
  console.log(color(heading));
  for (const line of lines) {
    if (line === "---") {
      console.log(color(`├${"─".repeat(width)}┤`));
    } else {
      const plain = strip(line);
      console.log(`${color("│")}  ${line}${" ".repeat(Math.max(0, width - plain.length - 2))}${color("│")}`);
    }
  }
  console.log(color(`╰${"─".repeat(width)}╯`));
}

function parseArgs(argv) {
  const options = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i].startsWith("--")) options[argv[i].slice(2)] = argv[i + 1];
  }
  return options;
}

function runPython(options) {
  return new Promise((resolve) => {
    const python = options.python || process.env.PYTHON || "python";
    const args = ["-m", "unittest", "discover", "-s", "tests", "-p", options.pattern, "-v"];
    const child = spawn(python, args, {
      cwd: process.cwd(),
      env: { ...process.env, PYTHONUTF8: "1" },
      shell: process.platform === "win32",
    });
    let output = "";
    child.stdout.on("data", (chunk) => { output += chunk; });
    child.stderr.on("data", (chunk) => { output += chunk; });
    child.on("error", (error) => resolve({ code: 1, output: `${output}\n${error}` }));
    child.on("close", (code) => resolve({ code: code ?? 1, output }));
  });
}

function parseResult(output) {
  const summary = output.match(/Ran\s+(\d+)\s+tests?.*?\n\s*(OK|FAILED)/s);
  const failed = output.match(/FAILED\s+\(([^)]*)\)/);
  const details = failed?.[1] || "";
  const read = (name) => Number(details.match(new RegExp(`${name}=(\\d+)`))?.[1] || 0);
  return {
    total: Number(summary?.[1] || 0),
    passed: summary?.[2] === "OK" ? Number(summary?.[1] || 0) : 0,
    failed: read("failures") + read("errors"),
    skipped: read("skipped"),
    ok: Boolean(summary && summary[2] === "OK"),
  };
}

function parseUnittestTests(output) {
  const lines = output.split(/\r?\n/);
  const tests = [];
  for (let index = 0; index < lines.length; index += 1) {
    if (!/^\s*test_/.test(lines[index])) continue;
    let record = lines[index];
    while (!/\.\.\.(?:.|\n)*?\b(ok|FAIL|ERROR|skipped|expected failure)\s*$/.test(record) && index + 1 < lines.length) {
      record += ` ${lines[++index].trim()}`;
    }
    const match = record.match(/^\s*(test_[^\s(]+).*?\.\.\.(?:.|\n)*?\b(ok|FAIL|ERROR|skipped|expected failure)\s*$/);
    if (!match) continue;
    const [, name, status] = match;
    const groupMatch = record.match(/\((test_[^.]+)\.([^.]+)/);
    tests.push({
      name,
      group: groupMatch?.[2] || "Python tests",
      status: status === "ok" ? "pass" : status === "skipped" ? "skip" : "fail",
    });
  }
  return tests;
}

function printTests(output) {
  const tests = parseUnittestTests(output);
  let group = "";
  for (const test of tests) {
    if (test.group !== group) {
      group = test.group;
      console.log(`\n${c.bold(c.cyan(group))}`);
    }
    const mark = test.status === "pass"
      ? c.green("✔")
      : test.status === "skip"
        ? c.yellow("○")
        : c.red("✖");
    console.log(`  ${mark} ${test.name}`);
  }
  return tests;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const title = options.title || "Python Agent tests";
  const subtitle = options.subtitle || "Unit tests";
  const started = Date.now();

  console.log();
  box([
    `${c.bold(c.cyan("▶"))} ${c.bold(title)}  ${c.gray("-")}  ${subtitle}`,
    c.gray(`Python unittest  ·  ${options.pattern}`),
  ]);

  const result = await runPython(options);
  const parsed = parseResult(result.output);
  const tests = printTests(result.output);
  const elapsed = Date.now() - started;

  if (!parsed.ok) {
    console.log(c.red("\n  ✖ Tests failed"));
    console.log(c.gray(result.output.trim()));
  }

  const badge = parsed.ok ? c.green(" PASS ") : c.red(" FAIL ");
  const passed = parsed.passed || tests.filter((test) => test.status === "pass").length;
  const failed = tests.filter((test) => test.status === "fail").length;
  const skipped = tests.filter((test) => test.status === "skip").length;
  const counts = parsed.ok
    ? `${c.green(`✔ ${passed} passed`)}${skipped ? `  ${c.yellow(`○ ${skipped} skipped`)}` : ""}  ${c.gray(`·  ${seconds(elapsed)}`)}`
    : `${c.red(`✖ ${failed} failed`)}  ${c.green(`✔ ${passed} passed`)}  ${c.gray(`·  ${seconds(elapsed)}`)}`;
  console.log(`\n  ${badge}  ${counts}\n`);
  process.exitCode = parsed.ok && result.code === 0 ? 0 : 1;
}

main();
