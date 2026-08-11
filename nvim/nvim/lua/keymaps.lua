local map = vim.keymap.set

map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })

map("n", "<leader>ff", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })

map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit window" })

map("n", "<C-h>", "<C-w>h", { desc = "Focus split left" })
map("n", "<C-l>", "<C-w>l", { desc = "Focus split right" })
map("n", "<C-j>", "<C-w>j", { desc = "Focus split down" })
map("n", "<C-k>", "<C-w>k", { desc = "Focus split up" })
