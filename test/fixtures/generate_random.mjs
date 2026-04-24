// Generate reference PRNG outputs from the JS Random class
// Run: node test/fixtures/generate_random.mjs > test/fixtures/random.json

class Random {
  constructor(seed) {
    this.seed = seed;
  }
  next() {
    if (this.seed) {
      return ((2 ** 31 - 1) & (this.seed = Math.imul(48271, this.seed))) / 2 ** 31;
    } else {
      return Math.random();
    }
  }
}

const result = {};
for (const seed of [1, 42, 12345, 999999]) {
  const r = new Random(seed);
  const values = [];
  for (let i = 0; i < 20; i++) {
    values.push(r.next());
  }
  result[seed] = values;
}

console.log(JSON.stringify(result, null, 2));
