vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("options")
require("keymaps")
require("lazy-bootstrap")

require("lazy").setup("plugins", {
    performance = {
        rtp = {
            disable = { "gzip", "netrwPlugin", "tarPlugin", "zipPlugin" },
        },
    },
})
