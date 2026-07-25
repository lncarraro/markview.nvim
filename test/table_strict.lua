local source = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(source))

vim.opt.runtimepath:prepend(root)
package.path = root .. '/lua/?.lua;' .. root .. '/lua/?/init.lua;' .. package.path

local markdown = require 'markview.renderers.markdown'
local spec = require 'markview.spec'

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
vim.api.nvim_win_set_buf(0, buffer)
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
  '|  Header  |',
  '| :------- |',
  '|  value   |',
})

local item = {
  top_border = false,
  bottom_border = false,
  border_overlap = false,
  alignments = { 'left' },
  has_alignment_markers = true,
  header = {
    { class = 'separator', text = '|', col_start = 0, col_end = 1 },
    { class = 'column', text = '  Header  ', col_start = 1, col_end = 11 },
    { class = 'separator', text = '|', col_start = 11, col_end = 12 },
  },
  separator = {
    { class = 'separator', text = '|', col_start = 0, col_end = 1 },
    { class = 'column', text = ' :------- ', col_start = 1, col_end = 11 },
    { class = 'separator', text = '|', col_start = 11, col_end = 12 },
  },
  rows = {
    {
      { class = 'separator', text = '|', col_start = 0, col_end = 1 },
      { class = 'column', text = '  value   ', col_start = 1, col_end = 11 },
      { class = 'separator', text = '|', col_start = 11, col_end = 12 },
    },
  },
  range = {
    row_start = 0,
    row_end = 3,
    col_start = 0,
    col_end = 12,
  },
}

local function strict_whitespace_marks(strict)
  spec.tmp_setup({
    markdown = {
      tables = {
        strict = strict,
      },
    },
  })

  vim.api.nvim_buf_clear_namespace(buffer, markdown.ns, 0, -1)
  markdown.table(buffer, item)

  local matches = {}

  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(
    buffer,
    markdown.ns,
    0,
    -1,
    { details = true }
  )) do
    local row, column, details = mark[2], mark[3], mark[4]

    if
      details.conceal == ''
      and (
        (row == 0 and (column == 2 or column == 9))
        or (row == 2 and (column == 2 or column == 8))
      )
    then
      table.insert(matches, { row, column, details.end_col })
    end
  end

  return matches
end

assert_equal(
  strict_whitespace_marks(false),
  {},
  'strict=false should preserve leading and trailing cell whitespace'
)

assert_equal(
  strict_whitespace_marks(true),
  {
    { 0, 2, 3 },
    { 0, 9, 10 },
    { 2, 2, 3 },
    { 2, 8, 10 },
  },
  'strict=true should conceal excess leading and trailing cell whitespace'
)

spec.tmp_reset()
print 'table_strict: 2 scenarios passed'
