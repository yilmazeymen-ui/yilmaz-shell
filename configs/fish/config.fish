# disable fish greeting
set fish_greeting

#===============================================#
#           enable starship prompt
#===============================================#
set --export STARSHIP_CONFIG ~/.config/fish/starship/starship-simple.toml

if status is-interactive
    function starship_transient_prompt_func
      starship module character
    end
    starship init fish | source
    enable_transience
end


#===============================================#
#           aliases
#===============================================#
alias ls='eza --color=always --icons=always'
# fastfetch: hangi preset (-c) kullanılırsa kullanılsın logo.txt'yi zorla
alias fastfetch='command fastfetch --file {{HOME}}/.config/fastfetch/logo.txt'

#===============================================#
#           functions
#===============================================#
source ~/.config/fish/functions/functions.fish
source ~/.config/fish/conf.d/personal.fish

#===============================================#
#           zoxide and thefuck
#===============================================#
zoxide init fish | source
thefuck --alias | source
alias fastfetch="fastfetch -c simple"


if status is-interactive
    bind \e\x7f backward-kill-word
    # Ctrl+Backspace: tam kelime sil (kitty 0x08 gönderir; düz Backspace 0x7f)
    bind \x08 backward-kill-word
end

if command -v fastfetch > /dev/null
    if status is-interactive
        # fastfetch -c simple
    end
end


function c
    if test -z "$argv[1]"
        # Eğer yanına bir şey yazmazsan ~/.config dizinine gitsin
        cd ~/.config
    else
        # Yazılan parametreyi ~/.config/ 'in sonuna ekleyip gitsin
        cd ~/.config/$argv[1]
    end
end
