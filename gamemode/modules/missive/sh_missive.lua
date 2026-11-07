-- ─── Module Missives ──────────────────────────────────────────────────────────
-- Système de lettres/messages entre personnages qui se connaissent.
-- DB  : verse_missives (sv_missive.lua)
-- UI  : cl_missive.lua  (touche M, ou bind configurable)
-- ─────────────────────────────────────────────────────────────────────────────

VERSE.Missive = VERSE.Missive or {}
local M = VERSE.Missive

M.Net = M.Net or {}
M.Net.List     = "VERSE::Missive::List"
M.Net.Send     = "VERSE::Missive::Send"
M.Net.Result   = "VERSE::Missive::Result"
M.Net.MarkRead = "VERSE::Missive::MarkRead"
M.Net.Notify   = "VERSE::Missive::Notify"

M.MaxTitleLen  = 80
M.MaxBodyLen   = 2000
M.MaxPerChar   = 50     -- missives max retournées par requête
