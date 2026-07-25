local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(source))

vim.opt.runtimepath:prepend(root)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local projection = require 'markview.renderers.markdown.table_projection'

local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(('%s\nexpected: %s\nactual: %s'):format(
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

local function screen_text(row, width)
  local text = ''

  for column = 1, width do
    text = text .. vim.fn.screenstring(row, column)
  end

  return text
end

local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_win_set_buf(0, buffer)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  '| A | B |',
  '| --- | --- |',
  '| abcdefghijklmnopqrstuvwxyz | value |',
})

vim.wo.wrap = false
vim.api.nvim_win_set_width(0, 18)

local config = {
  block_decorator = false,
  parts = {
    header = { '|', '|', '|' },
    separator = { '|', '-', '|', '+' },
    row = { '|', '|', '|' },
    align_left = '<',
    align_right = '>',
    align_center = { '<', '>' },
  },
  hl = {},
}

projection.render(
  buffer,
  vim.api.nvim_create_namespace 'table-projection-test',
  {
    alignments = { 'left', 'left' },
    top_border = false,
    bottom_border = false,
    range = {
      row_start = 0,
      row_end = 3,
      col_start = 0,
    },
  },
  config,
  {
    header = { ' A ', ' B ' },
    rows = {
      { ' abcdefghijklmnopqrstuvwxyz ', ' value ' },
    },
  },
  { 28, 7 },
  false
)

vim.api.nvim_win_set_cursor(0, { 3, 20 })
vim.fn.winrestview { leftcol = 0 }
vim.cmd 'redraw'

assert_equal(
  screen_text(1, 18),
  '| A               ',
  'the projected header should render at its natural padded width'
)

vim.fn.winrestview { leftcol = 16 }
vim.cmd 'redraw'

assert_equal(
  vim.fn.winsaveview().leftcol,
  16,
  'the test window should scroll horizontally'
)
assert_equal(
  screen_text(1, 18),
  '             | B  ',
  'a projected row should move with the buffer horizontal scroll'
)

projection.clear(buffer)
vim.cmd 'redraw'

assert_equal(
  screen_text(1, 10),
  '          ',
  'clearing the projection should remove its redraw decoration'
)

print 'table_projection: 3 scenarios passed'
