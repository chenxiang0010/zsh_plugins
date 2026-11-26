# fzf-history-prefix
#
# 「输入开头 + ↑」按前缀检索历史，弹出 fzf 面板：
#   - 有前缀且匹配多条  → fzf 面板只列以该前缀开头的历史（最新在前、按行去重）
#   - 有前缀且只命中一条 → 直接填入，不弹面板
#   - 有前缀但无匹配     → 退回原生 history-beginning-search-backward
#   - 前缀为空           → 普通上一条历史
#
# 原先这能力来自 oh-my-zsh 的 lib/key-bindings.zsh（把 ↑ 绑到
# up-line-or-beginning-search），改用 sheldon 后该文件不再加载，故在此自建。
#
# 调参：FZF_HISTORY_CMD（替换 fzf 可执行文件，测试用）、FZF_HISTORY_OPTS（追加选项）。

autoload -Uz down-line-or-beginning-search
zle -N down-line-or-beginning-search

fzf-history-prefix-widget() {
  emulate -L zsh
  setopt localoptions noglobsubst noposixbuiltins no_glob no_sh_glob no_ksharrays extendedglob no_aliases pipefail
  local prefix=$LBUFFER
  local fzfcmd=${FZF_HISTORY_CMD:-fzf}
  zmodload -F zsh/parameter p:history 2>/dev/null
  if [[ -z $prefix || ( -z $commands[$fzfcmd] && -z ${FZF_HISTORY_CMD-} ) ]]; then
    zle .up-line-or-history
    return
  fi
  local -a matches
  local -A seen
  local ev line
  for ev in ${(On)${(k)history}}; do      # 事件号降序 = 最新在前
    line=${history[$ev]}
    [[ -z $line ]] && continue
    [[ $line == "$prefix"* ]] || continue
    (( ${+seen[$line]} )) && continue
    seen[$line]=1
    matches+=("$line")
  done
  if (( ! ${#matches} )); then
    zle .history-beginning-search-backward
    return
  fi
  if (( ${#matches} == 1 )); then
    if [[ ${matches[1]} == $BUFFER ]]; then
      zle .history-beginning-search-backward
    else
      BUFFER=${matches[1]}
      CURSOR=${#BUFFER}
      zle reset-prompt
    fi
    return
  fi
  local selected
  selected=$(printf '%s\0' "${matches[@]}" |
    $fzfcmd --read0 --no-multi --exact --no-sort --scheme=history \
      --height=40% --min-height=20+ --reverse \
      --border=rounded --border-label=' HISTORY ' --border-label-pos=3 \
      --prompt="$prefix " --pointer='▶ ' \
      --footer=' ↑ ↓ to navigate   enter to accept   esc to dismiss ' \
      ${=FZF_HISTORY_OPTS-})
  if [[ -n $selected ]]; then
    BUFFER=$selected
    CURSOR=${#BUFFER}
  fi
  zle reset-prompt
}
zle -N fzf-history-prefix-widget

for _kc in '^[[A' '^[OA' "${terminfo[kcuu1]}"; do
  [[ -n "$_kc" ]] && bindkey -M emacs "$_kc" fzf-history-prefix-widget
  [[ -n "$_kc" ]] && bindkey -M viins  "$_kc" fzf-history-prefix-widget
done
for _kc in '^[[B' '^[OB' "${terminfo[kcud1]}"; do
  [[ -n "$_kc" ]] && bindkey -M emacs "$_kc" down-line-or-beginning-search
  [[ -n "$_kc" ]] && bindkey -M viins  "$_kc" down-line-or-beginning-search
done
unset _kc
