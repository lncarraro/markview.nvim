local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(source))

vim.opt.runtimepath:prepend(root)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local markdown = require 'markview.renderers.markdown'

local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(('%s\nexpected: %s\nactual: %s'):format(
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  '| State | Meaning |',
  '| ----- | ------- |',
  '| done  | complete |',
  '',
  '# Next section',
})

markdown.table_bottom_padding(buffer, {
  bottom_border = true,
  range = { row_end = 3 },
}, 1)

local marks = vim.api.nvim_buf_get_extmarks(
  buffer,
  markdown.ns,
  0,
  -1,
  { details = true }
)

assert_equal(#marks, 1, 'one padding extmark should be created')
assert_equal(marks[1][2], 3, 'padding should be anchored to the bottom-border row')
assert_equal(#marks[1][4].virt_lines, 1, 'one virtual blank line should be rendered')

vim.api.nvim_buf_clear_namespace(buffer, markdown.ns, 0, -1)
markdown.table_bottom_padding(buffer, {
  bottom_border = true,
  range = { row_end = 3 },
}, 0)

marks = vim.api.nvim_buf_get_extmarks(buffer, markdown.ns, 0, -1, {})
assert_equal(#marks, 0, 'zero padding should preserve the existing rendering')

vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  '| State | Meaning |',
  '| ----- | ------- |',
  '| done  | complete |',
})

markdown.table_bottom_padding(buffer, {
  bottom_border = false,
  range = { row_end = 3 },
}, 1)

marks = vim.api.nvim_buf_get_extmarks(buffer, markdown.ns, 0, -1, {})
assert_equal(#marks, 0, 'a table at end of file should not add trailing padding')

print 'table_bottom_padding: 3 scenarios passed'
