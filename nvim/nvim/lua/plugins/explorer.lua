return {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = "NvimTreeToggle",
    keys = {
        { "<leader>e", desc = "Toggle file explorer" },
    },
    opts = {
        view = { width = 30 },
        renderer = { group_empty = true },
        filters = { dotfiles = false },
    },
}
