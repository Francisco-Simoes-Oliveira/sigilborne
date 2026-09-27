const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { createRequire } = require('node:module');

module.exports = function load(relativePath, dependencies) {
  const filename = path.join(__dirname, '../..', relativePath);
  const normalRequire = createRequire(filename);
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(filename, 'utf8'), {
    module, exports: module.exports, Date,
    require: name => Object.hasOwn(dependencies, name) ? dependencies[name] : normalRequire(name),
    console: { error() {} },
  }, { filename });
  return module.exports;
};
