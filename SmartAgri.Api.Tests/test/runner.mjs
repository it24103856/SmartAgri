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

function box(lines, color = c.cyan, title = "") {
  const width = 68;
  const heading = `╭─ ${c.bold(title)} ${"─".repeat(Math.max(1, width - title.length - 4))}╮`;
  console.log(color(heading));
  for (const line of lines) {
    const plain = strip(line);
    console.log(`${color("│")}  ${line}${" ".repeat(Math.max(0, width - plain.length - 2))}${color("│")}`);
  }
  console.log(color(`╰${"─".repeat(width)}╯`));
}

function options(argv) {
  const result = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i].startsWith("--")) result[argv[i].slice(2)] = argv[i + 1];
  }
  return result;
}

function runDotnet(opts) {
  return new Promise((resolve) => {
    const args = [
      "test",
      opts.project || "SmartAgri.Api.Tests.csproj",
      "--configuration",
      opts.config || "Release",
      "--logger",
      "console;verbosity=normal",
      "--no-restore",
    ];
    if (opts.filter) args.push("--filter", opts.filter);
    const child = spawn("dotnet", args, {
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

function parseTestLines(output) {
  return output.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*(Passed|Failed|Skipped)\s+(.+?)\s+\[(.+?)\]\s*$/);
    if (!match) return [];
    const [, status, fullName, time] = match;
    const parts = fullName.split(".");
    return [{
      status: status === "Passed" ? "pass" : status === "Skipped" ? "skip" : "fail",
      group: parts.at(-2) || "Backend tests",
      name: parts.at(-1),
      time: time.replace(/\s/g, ""),
    }];
  });
}

function parseSummary(output) {
  const match = output.match(/(?:Passed|Failed)!\s+-\s+Failed:\s+(\d+),\s+Passed:\s+(\d+),\s+Skipped:\s+(\d+),\s+Total:\s+(\d+)/);
  if (match) {
    return {
      failed: Number(match[1]),
      passed: Number(match[2]),
      skipped: Number(match[3]),
      total: Number(match[4]),
    };
  }
  const normal = output.match(
    /Total tests:\s+(\d+)\s+[\s\S]*?Passed:\s+(\d+)(?:\s+[\s\S]*?Failed:\s+(\d+))?(?:\s+[\s\S]*?Skipped:\s+(\d+))?/,
  );
  return normal
    ? {
        total: Number(normal[1]),
        passed: Number(normal[2]),
        failed: Number(normal[3] || 0),
        skipped: Number(normal[4] || 0),
      }
    : null;
}

async function main() {
  const opts = options(process.argv.slice(2));
  const started = Date.now();
  const title = opts.title || "Backend tests";
  const subtitle = opts.subtitle || "ASP.NET Core API";

  console.log();
  box([
    `${c.bold(c.cyan("▶"))} ${c.bold(title)}  ${c.gray("-")}  ${subtitle}`,
    c.gray(`.NET test project  ·  ${opts.filter ? "filtered" : "all tests"}`),
  ]);

  const result = await runDotnet(opts);
  const tests = parseTestLines(result.output);
  const summary = parseSummary(result.output);
  let group = "";

  for (const test of tests) {
    if (test.group !== group) {
      group = test.group;
      console.log(`\n${c.bold(c.cyan(group))}`);
    }
    const mark = test.status === "pass" ? c.green("✔") : test.status === "skip" ? c.yellow("○") : c.red("✖");
    console.log(`  ${mark} ${test.name}  ${c.gray(test.time)}`);
  }

  const elapsed = Date.now() - started;
  const ok = result.code === 0 && summary && summary.failed === 0;
  if (!ok && !summary) console.log(c.red(`\n${result.output.trim()}`));

  const badge = ok ? c.green(" PASS ") : c.red(" FAIL ");
  const counts = summary
    ? `${c.green(`✔ ${summary.passed} passed`)}  ${summary.failed ? c.red(`✖ ${summary.failed} failed`) : c.gray("✖ 0 failed")}  ${summary.skipped ? c.yellow(`○ ${summary.skipped} skipped`) : ""}`
    : c.red("no test summary");
  console.log(`\n  ${badge}  ${counts}  ${c.gray(`·  ${seconds(elapsed)}`)}\n`);
  if (!ok && summary) console.log(c.gray(result.output.split(/\r?\n/).slice(-35).join("\n")));
  process.exitCode = ok ? 0 : 1;
}

main();
