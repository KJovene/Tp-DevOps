const test = require("node:test");
const assert = require("node:assert/strict");

const { add, divide, multiply } = require("../src/math");

test("add returns the sum of two numbers", () => {
  assert.equal(add(2, 3), 5);
});

test("multiply returns the product of two numbers", () => {
  assert.equal(multiply(3, 4), 12);
});

test("divide throws when dividing by zero", () => {
  assert.throws(() => divide(1, 0), /Division by zero/);
});
