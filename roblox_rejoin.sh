#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#   ROBLOX AUTO-REJOIN TOOL v2 - TERMUX ROOT
#   Phat hien: process chet | ket Home Roblox | man den/treo
# ============================================================

RED='\033[0;31m';    GREEN='\033[0;32m';  YELLOW='\033[1;33m'
CYAN='\033[0;36m';   BLUE='\033[0;34m';   MAGENTA='\033[0;35m'
WHITE='\033[1;37m';  BOLD='\033[1m';      RESET='\033[0m'

ROBLOX_PKG=""
PLACE_ID=""
DELAY_CHECK=5
DELAY_REJOIN=10
DELAY_LOADING=30
BLACK_SCREEN_TIMEOUT=25
HOME_STUCK_TIMEOUT=20

IS_RUNNING=false
LOG_FILE="$HOME/roblox_rejoin.log"
REJOIN_COUNT=0
LAST_STATE=""
STATE_SINCE=0
LAST_GAME_ACTIVITY=""
FIRST_JOIN_DONE=false
TMP_SCREEN="/data/local/tmp/rbx_check.png"

ROBLOX_PACKAGES=(
    "com.roblox.client"
    "com.roblox.robloxmobile"
    "com.roblox.client.beta"
)

# ----------------------------------------------------------------

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

now() {
    date +%s
}

elapsed_since() {
    echo $(( $(now) - $1 ))
}

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ██████╗  ██████╗ ██████╗ ██╗      ██████╗ ██╗  ██╗"
    echo "  ██╔══██╗██╔═══██╗██╔══██╗██║     ██╔═══██╗╚██╗██╔╝"
    echo "  ██████╔╝██║   ██║██████╔╝██║     ██║   ██║ ╚███╔╝ "
    echo "  ██╔══██╗██║   ██║██╔══██╗██║     ██║   ██║ ██╔██╗ "
    echo "  ██║  ██║╚██████╔╝██████╔╝███████╗╚██████╔╝██╔╝ ██╗"
    echo "  ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${RESET}${MAGENTA}${BOLD}        AUTO REJOIN v2 - SMART DETECT${RESET}"
    echo -e "${WHITE}  ────────────────────────────────────────────────────${RESET}"
    echo -e "${YELLOW}  Package : ${WHITE}${ROBLOX_PKG:-Chua nhan dien}${RESET}"
    echo -e "${YELLOW}  Place ID: ${WHITE}${PLACE_ID:-Chua thiet lap}${RESET}"
    if [ "$IS_RUNNING" = true ]; then
        echo -e "${YELLOW}  Trang thai: ${GREEN}DANG CHAY [ON]${RESET}"
    else
        echo -e "${YELLOW}  Trang thai: ${RED}DUNG [OFF]${RESET}"
    fi
    echo -e "${YELLOW}  Da rejoin: ${WHITE}${REJOIN_COUNT} lan${RESET}"
    echo -e "${WHITE}  ────────────────────────────────────────────────────${RESET}"
    echo ""
}

# ----------------------------------------------------------------

check_root() {
    if ! su -c "echo ok" > /dev/null 2>&1; then
        echo -e "${RED}[LOI] May chua root hoac Termux chua duoc cap quyen su!${RESET}"
        exit 1
    fi
}

auto_detect_roblox() {
    echo -e "${CYAN}[*] Dang nhan dien Roblox...${RESET}"
    local pkg
    for pkg in "${ROBLOX_PACKAGES[@]}"; do
        if su -c "pm list packages 2>/dev/null" | grep -q "$pkg"; then
            ROBLOX_PKG="$pkg"
            echo -e "${GREEN}[OK] Tim thay: ${WHITE}$ROBLOX_PKG${RESET}"
            log "Nhan dien Roblox: $ROBLOX_PKG"
            sleep 1
            return
        fi
    done
    echo -e "${RED}[X] Khong tim thay Roblox tu dong.${RESET}"
    echo -ne "${YELLOW}Nhap package name thu cong: ${RESET}"
    read -r ROBLOX_PKG
    if [ -z "$ROBLOX_PKG" ]; then
        echo -e "${RED}Khong co package, thoat.${RESET}"
        exit 1
    fi
    sleep 1
}

# ----------------------------------------------------------------

is_roblox_running() {
    su -c "pidof '$ROBLOX_PKG'" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    fi
    su -c "ps -A 2>/dev/null | grep -q '$ROBLOX_PKG'"
    return $?
}

get_current_focus() {
    su -c "dumpsys window windows 2>/dev/null" \
        | grep -E "mCurrentFocus|mFocusedApp" \
        | head -2
}

is_roblox_foreground() {
    get_current_focus | grep -qi "$ROBLOX_PKG"
}

get_roblox_resumed_activity() {
    su -c "dumpsys activity activities 2>/dev/null" \
        | grep -i "mResumedActivity" \
        | grep -i "$ROBLOX_PKG" \
        | head -1 \
        | sed 's/.*{[^ ]* [^ ]* \([^ ]*\).*/\1/'
}

check_black_screen() {
    su -c "screencap -p '$TMP_SCREEN'" > /dev/null 2>&1
    if [ ! -f "$TMP_SCREEN" ]; then
        return 1
    fi
    local fsize
    fsize=$(wc -c < "$TMP_SCREEN" 2>/dev/null || echo 999999)
    su -c "rm -f '$TMP_SCREEN'" > /dev/null 2>&1
    if [ "$fsize" -lt 30720 ]; then
        return 0
    fi
    return 1
}

detect_state() {
    if ! is_roblox_running; then
        echo "DEAD"
        return
    fi

    if ! is_roblox_foreground; then
        echo "BACKGROUND"
        return
    fi

    local activity
    activity=$(get_roblox_resumed_activity)

    if check_black_screen; then
        echo "BLACK"
        return
    fi

    if echo "$activity" | grep -qiE "MainActivity|AppShell|HomeActivity|SplashActivity|LoginActivity|StartupActivity|LaunchActivity|BootActivity|Hub|Portal|LandingActivity"; then
        echo "HOME"
        return
    fi

    if [ -n "$LAST_GAME_ACTIVITY" ] && [ "$activity" = "$LAST_GAME_ACTIVITY" ]; then
        echo "GAME"
        return
    fi

    if [ "$FIRST_JOIN_DONE" = false ]; then
        echo "LOADING"
        return
    fi

    if [ -n "$LAST_GAME_ACTIVITY" ] && [ "$activity" != "$LAST_GAME_ACTIVITY" ]; then
        echo "HOME"
        return
    fi

    echo "LOADING"
}

# ----------------------------------------------------------------

send_join_intent() {
    su -c "am start -a android.intent.action.VIEW -d 'roblox://placeId=${PLACE_ID}' '${ROBLOX_PKG}'" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        su -c "am start -p '${ROBLOX_PKG}'" > /dev/null 2>&1
        sleep 2
        su -c "am start -a android.intent.action.VIEW -d 'roblox://placeId=${PLACE_ID}'" > /dev/null 2>&1
    fi
}

force_stop_and_rejoin() {
    echo -e "${YELLOW}  -> Force stop Roblox...${RESET}"
    su -c "am force-stop '${ROBLOX_PKG}'" > /dev/null 2>&1
    sleep 3
    FIRST_JOIN_DONE=false
    LAST_GAME_ACTIVITY=""
    send_join_intent
}

do_rejoin() {
    local reason="$1"
    REJOIN_COUNT=$(( REJOIN_COUNT + 1 ))
    log "=== REJOIN #${REJOIN_COUNT} | Ly do: ${reason} | PlaceID=${PLACE_ID} ==="
    echo -e "${MAGENTA}[REJOIN #${REJOIN_COUNT}] Ly do: ${reason}${RESET}"
}

# ----------------------------------------------------------------

start_rejoin_loop() {
    if [ -z "$PLACE_ID" ]; then
        echo -e "${RED}[!] Chua thiet lap Place ID!${RESET}"
        sleep 2
        return
    fi
    if [ -z "$ROBLOX_PKG" ]; then
        echo -e "${RED}[!] Chua nhan dien package Roblox!${RESET}"
        sleep 2
        return
    fi

    IS_RUNNING=true
    REJOIN_COUNT=0
    FIRST_JOIN_DONE=false
    LAST_GAME_ACTIVITY=""
    LAST_STATE=""
    STATE_SINCE=$(now)

    echo ""
    echo -e "${GREEN}${BOLD}[OK] Bat dau Auto Rejoin Loop!${RESET}"
    echo -e "  Place ID : ${CYAN}${PLACE_ID}${RESET}"
    echo -e "  Package  : ${CYAN}${ROBLOX_PKG}${RESET}"
    echo -e "  Kiem tra : moi ${CYAN}${DELAY_CHECK}s${RESET}"
    echo -e "${YELLOW}  Nhan Ctrl+C de dung va quay lai menu${RESET}"
    echo ""
    log "=== LOOP BAT DAU | PlaceID=${PLACE_ID} | Pkg=${ROBLOX_PKG} ==="

    echo -e "${CYAN}[INIT] Mo Roblox game lan dau...${RESET}"
    force_stop_and_rejoin
    echo -e "${CYAN}[INIT] Cho ${DELAY_LOADING}s de game tai...${RESET}"
    sleep "$DELAY_LOADING"

    while true; do
        sleep "$DELAY_CHECK"
        local ts state elapsed
        ts=$(date '+%H:%M:%S')
        state=$(detect_state)
        elapsed=$(elapsed_since "$STATE_SINCE")

        if [ "$state" != "$LAST_STATE" ]; then
            STATE_SINCE=$(now)
            elapsed=0
            log "Trang thai doi: ${LAST_STATE} -> ${state}"
        fi
        LAST_STATE="$state"

        case "$state" in
            GAME)
                FIRST_JOIN_DONE=true
                local act
                act=$(get_roblox_resumed_activity)
                if [ -n "$act" ]; then
                    LAST_GAME_ACTIVITY="$act"
                fi
                echo -e "${GREEN}[${ts}] TRONG GAME OK | Rejoin: ${REJOIN_COUNT}x${RESET}"
                ;;

            LOADING)
                echo -e "${CYAN}[${ts}] LOADING... (${elapsed}s)${RESET}"
                if [ "$elapsed" -gt 180 ]; then
                    echo -e "${RED}[${ts}] Loading qua lau (${elapsed}s)! Force restart...${RESET}"
                    do_rejoin "Loading qua lau (${elapsed}s)"
                    force_stop_and_rejoin
                    echo -e "${CYAN}Cho ${DELAY_LOADING}s...${RESET}"
                    sleep "$DELAY_LOADING"
                    STATE_SINCE=$(now)
                fi
                ;;

            HOME)
                echo -e "${YELLOW}[${ts}] KET HOME ROBLOX (${elapsed}s / can ${HOME_STUCK_TIMEOUT}s)${RESET}"
                if [ "$elapsed" -ge "$HOME_STUCK_TIMEOUT" ]; then
                    do_rejoin "Ket Home Roblox (${elapsed}s)"
                    echo -e "${CYAN}  -> Gui lai lenh vao game (khong kill)...${RESET}"
                    send_join_intent
                    echo -e "${CYAN}  -> Cho ${DELAY_REJOIN}s...${RESET}"
                    sleep "$DELAY_REJOIN"
                    STATE_SINCE=$(now)
                    LAST_STATE=""
                    sleep "$DELAY_CHECK"
                    local recheck
                    recheck=$(detect_state)
                    if [ "$recheck" = "HOME" ]; then
                        echo -e "${RED}  -> Van ket HOME! Force stop + rejoin...${RESET}"
                        log "Van ket HOME sau intent, force stop"
                        force_stop_and_rejoin
                        echo -e "${CYAN}  -> Cho ${DELAY_LOADING}s...${RESET}"
                        sleep "$DELAY_LOADING"
                        STATE_SINCE=$(now)
                        LAST_STATE=""
                    fi
                fi
                ;;

            BLACK)
                echo -e "${RED}[${ts}] MAN HINH DEN/TREO (${elapsed}s / can ${BLACK_SCREEN_TIMEOUT}s)${RESET}"
                if [ "$elapsed" -ge "$BLACK_SCREEN_TIMEOUT" ]; then
                    do_rejoin "Man hinh den (${elapsed}s)"
                    echo -e "${RED}  -> Force stop + rejoin...${RESET}"
                    log "Man den qua lau: force stop"
                    force_stop_and_rejoin
                    echo -e "${CYAN}  -> Cho ${DELAY_LOADING}s...${RESET}"
                    sleep "$DELAY_LOADING"
                    STATE_SINCE=$(now)
                    LAST_STATE=""
                fi
                ;;

            DEAD)
                echo -e "${RED}[${ts}] ROBLOX CHET! Dang rejoin...${RESET}"
                do_rejoin "Process chet"
                force_stop_and_rejoin
                echo -e "${CYAN}  -> Cho ${DELAY_LOADING}s game tai...${RESET}"
                sleep "$DELAY_LOADING"
                STATE_SINCE=$(now)
                LAST_STATE=""
                ;;

            BACKGROUND)
                echo -e "${BLUE}[${ts}] Roblox chay nen (${elapsed}s)${RESET}"
                if [ "$elapsed" -ge 10 ]; then
                    echo -e "${CYAN}  -> Dua Roblox len foreground...${RESET}"
                    su -c "am start -p '${ROBLOX_PKG}'" > /dev/null 2>&1
                    sleep 3
                    STATE_SINCE=$(now)
                    LAST_STATE=""
                fi
                ;;

            *)
                echo -e "${YELLOW}[${ts}] Trang thai: ${state}${RESET}"
                ;;
        esac
    done

    IS_RUNNING=false
}

# ----------------------------------------------------------------

menu_settings() {
    local opt v
    while true; do
        print_banner
        echo -e "  ${BOLD}${WHITE}CAI DAT${RESET}"
        echo ""
        echo -e "  ${CYAN}1.${RESET} Place ID          : ${YELLOW}${PLACE_ID:-Chua dat}${RESET}"
        echo -e "  ${CYAN}2.${RESET} Check moi (s)     : ${YELLOW}${DELAY_CHECK}s${RESET}"
        echo -e "  ${CYAN}3.${RESET} Cho rejoin (s)    : ${YELLOW}${DELAY_REJOIN}s${RESET}"
        echo -e "  ${CYAN}4.${RESET} Timeout loading   : ${YELLOW}${DELAY_LOADING}s${RESET}"
        echo -e "  ${CYAN}5.${RESET} Timeout man den   : ${YELLOW}${BLACK_SCREEN_TIMEOUT}s${RESET}"
        echo -e "  ${CYAN}6.${RESET} Timeout Home ket  : ${YELLOW}${HOME_STUCK_TIMEOUT}s${RESET}"
        echo -e "  ${CYAN}7.${RESET} Nhan dien lai Roblox"
        echo -e "  ${CYAN}8.${RESET} Dat package thu cong"
        echo -e "  ${CYAN}0.${RESET} Quay lai"
        echo ""
        read -rp "$(echo -e "${WHITE}  Chon: ${RESET}")" opt
        case "$opt" in
            1)
                echo -ne "${YELLOW}  Nhap Place ID (chi so): ${RESET}"
                read -r v
                if echo "$v" | grep -qE '^[0-9]+$'; then
                    PLACE_ID="$v"
                    echo -e "${GREEN}  [OK] Place ID: $PLACE_ID${RESET}"
                else
                    echo -e "${RED}  [!] Phai la so!${RESET}"
                fi
                sleep 1
                ;;
            2)
                echo -ne "${YELLOW}  Check moi X giay (>=2): ${RESET}"
                read -r v
                if echo "$v" | grep -qE '^[0-9]+$' && [ "$v" -ge 2 ]; then
                    DELAY_CHECK="$v"
                    echo -e "${GREEN}  [OK] ${DELAY_CHECK}s${RESET}"
                else
                    echo -e "${RED}  [!] Toi thieu 2s${RESET}"
                fi
                sleep 1
                ;;
            3)
                echo -ne "${YELLOW}  Cho rejoin X giay (>=3): ${RESET}"
                read -r v
                if echo "$v" | grep -qE '^[0-9]+$' && [ "$v" -ge 3 ]; then
                    DELAY_REJOIN="$v"
                    echo -e "${GREEN}  [OK] ${DELAY_REJOIN}s${RESET}"
                else
                    echo -e "${RED}  [!] Toi thieu 3s${RESET}"
                fi
                sleep 1
                ;;
            4)
                echo -ne "${YELLOW}  Timeout loading (>=15s): ${RESET}"
                read -r v
                if echo "$v" | grep -qE '^[0-9]+$' && [ "$v" -ge 15 ]; then
                    DELAY_LOADING="$v"
                    echo -e "${GREEN}  [OK] ${DELAY_LOADING}s${RESET}"
                else
                    echo -e "${RED}  [!] Toi thieu 15s${RESET}"
                fi
                sleep 1
                ;;
            5)
                echo -ne "${YELLOW}  Timeout man den (>=10s): ${RESET}"
                read -r v
                if echo "$v" | grep -qE '^[0-9]+$' && [ "$v" -ge 10 ]; then
                    BLACK_SCREEN_TIMEOUT="$v"
                    echo -e "${GREEN}  [OK] ${BLACK_SCREEN_TIMEOUT}s${RESET}"
                else
                    echo -e "${RED}  [!] Toi thieu 10s${RESET}"
                fi
                sleep 1
                ;;
            6)
                echo -ne "${YELLOW}  Timeout Home ket (>=10s): ${RESET}"
                read -r v
                if echo "$v" | grep -qE '^[0-9]+$' && [ "$v" -ge 10 ]; then
                    HOME_STUCK_TIMEOUT="$v"
                    echo -e "${GREEN}  [OK] ${HOME_STUCK_TIMEOUT}s${RESET}"
                else
                    echo -e "${RED}  [!] Toi thieu 10s${RESET}"
                fi
                sleep 1
                ;;
            7)
                auto_detect_roblox
                ;;
            8)
                echo -ne "${YELLOW}  Package (vd: com.roblox.client): ${RESET}"
                read -r v
                if [ -n "$v" ]; then
                    ROBLOX_PKG="$v"
                    echo -e "${GREEN}  [OK] $ROBLOX_PKG${RESET}"
                fi
                sleep 1
                ;;
            0)
                return
                ;;
        esac
    done
}

menu_test() {
    local topt
    print_banner
    echo -e "  ${BOLD}${WHITE}KIEM TRA & TEST${RESET}"
    echo ""
    echo -e "  ${CYAN}1.${RESET} Phat hien trang thai ngay bay gio"
    echo -e "  ${CYAN}2.${RESET} Kiem tra man hinh den"
    echo -e "  ${CYAN}3.${RESET} Mo game (gui intent 1 lan)"
    echo -e "  ${CYAN}4.${RESET} Force stop Roblox"
    echo -e "  ${CYAN}5.${RESET} Xem foreground activity"
    echo -e "  ${CYAN}6.${RESET} Xem process Roblox"
    echo -e "  ${CYAN}0.${RESET} Quay lai"
    echo ""
    read -rp "$(echo -e "${WHITE}  Chon: ${RESET}")" topt
    case "$topt" in
        1)
            echo ""
            local s
            s=$(detect_state)
            case "$s" in
                GAME)       echo -e "${GREEN}  -> TRONG GAME OK${RESET}" ;;
                HOME)       echo -e "${YELLOW}  -> KET HOME ROBLOX${RESET}" ;;
                LOADING)    echo -e "${CYAN}  -> DANG LOADING...${RESET}" ;;
                BLACK)      echo -e "${RED}  -> MAN HINH DEN${RESET}" ;;
                DEAD)       echo -e "${RED}  -> ROBLOX KHONG CHAY${RESET}" ;;
                BACKGROUND) echo -e "${BLUE}  -> ROBLOX CHAY NEN${RESET}" ;;
                *)          echo -e "${YELLOW}  -> ${s}${RESET}" ;;
            esac
            sleep 3
            ;;
        2)
            echo ""
            if check_black_screen; then
                echo -e "${RED}  -> MAN HINH DEN phat hien!${RESET}"
            else
                echo -e "${GREEN}  -> Man hinh binh thuong${RESET}"
            fi
            sleep 3
            ;;
        3)
            echo ""
            send_join_intent
            echo -e "${GREEN}  [OK] Da gui intent vao game!${RESET}"
            sleep 2
            ;;
        4)
            echo ""
            su -c "am force-stop '$ROBLOX_PKG'" > /dev/null 2>&1
            echo -e "${GREEN}  [OK] Da force stop!${RESET}"
            sleep 2
            ;;
        5)
            echo ""
            echo -e "${CYAN}  Foreground activity:${RESET}"
            get_current_focus
            echo ""
            echo -e "${CYAN}  Resumed activity:${RESET}"
            get_roblox_resumed_activity
            echo ""
            sleep 4
            ;;
        6)
            echo ""
            echo -e "${CYAN}  Process Roblox:${RESET}"
            su -c "ps -A 2>/dev/null | grep -i roblox" || echo -e "${YELLOW}  (khong co)${RESET}"
            sleep 3
            ;;
    esac
}

menu_log() {
    local lopt
    print_banner
    echo -e "  ${BOLD}${WHITE}LOG: $LOG_FILE${RESET}"
    echo ""
    if [ -f "$LOG_FILE" ]; then
        tail -40 "$LOG_FILE"
        echo ""
        echo -e "  ${CYAN}1.${RESET} Xoa log  ${CYAN}0.${RESET} Quay lai"
        read -rp "$(echo -e "${WHITE}  Chon: ${RESET}")" lopt
        if [ "$lopt" = "1" ]; then
            : > "$LOG_FILE"
            echo -e "${GREEN}  [OK] Da xoa log${RESET}"
            sleep 1
        fi
    else
        echo -e "${YELLOW}  Chua co log.${RESET}"
        sleep 2
    fi
}

show_guide() {
    print_banner
    echo -e "${BOLD}${WHITE}  HUONG DAN SU DUNG${RESET}"
    echo ""
    echo -e "${YELLOW}  YEU CAU:${RESET}"
    echo -e "  - Android da root (Magisk hoac SuperSU)"
    echo -e "  - Termux duoc cap quyen su"
    echo -e "  - Roblox da cai tren may"
    echo ""
    echo -e "${YELLOW}  CAC BUOC SU DUNG:${RESET}"
    echo -e "  1. bash ~/rjoin.sh"
    echo -e "  2. Tool tu nhan dien Roblox"
    echo -e "  3. Chon [1 Cai dat] -> Nhap Place ID"
    echo -e "     Place ID la so trong URL:"
    echo -e "     roblox.com/games/4483381587/ten-game"
    echo -e "  4. Chon [2 Bat dau] -> tool tu chay lien tuc"
    echo ""
    echo -e "${YELLOW}  TRUONG HOP DUOC XU LY:${RESET}"
    echo -e "  [DEAD]  Roblox chet hoan toan    -> Force stop + mo lai"
    echo -e "  [HOME]  Ket o Home Roblox         -> Gui intent vao game"
    echo -e "          (neu van ket -> force stop + mo lai)"
    echo -e "  [BLACK] Man hinh den / treo       -> Force stop + mo lai"
    echo -e "  [LOAD]  Loading qua lau (3 phut) -> Force stop + mo lai"
    echo -e "  [BG]    Roblox bi day xuong nen  -> Dua len foreground"
    echo ""
    echo -e "${YELLOW}  CHAY NEN (KHONG TAT KHI DONG TERMUX):${RESET}"
    echo -e "  pkg install tmux"
    echo -e "  tmux new -s roblox"
    echo -e "  bash ~/rjoin.sh"
    echo -e "  Nhan Ctrl+B roi D de an session"
    echo -e "  Quay lai: tmux attach -t roblox"
    echo ""
    read -rp "$(echo -e "${WHITE}  Nhan Enter de quay lai...${RESET}")"
}

# ----------------------------------------------------------------

main() {
    check_root
    auto_detect_roblox

    local choice
    while true; do
        print_banner
        echo -e "  ${BOLD}${WHITE}MENU CHINH${RESET}"
        echo ""
        echo -e "  ${GREEN}1.${RESET} Cai dat (Place ID, timeout...)"
        echo -e "  ${GREEN}2.${RESET} Bat dau Auto Rejoin"
        echo -e "  ${GREEN}3.${RESET} Kiem tra & Test"
        echo -e "  ${GREEN}4.${RESET} Xem Log"
        echo -e "  ${GREEN}5.${RESET} Huong dan su dung"
        echo -e "  ${RED}0.${RESET} Thoat"
        echo ""
        read -rp "$(echo -e "${WHITE}  Chon: ${RESET}")" choice
        case "$choice" in
            1)
                menu_settings
                ;;
            2)
                IS_RUNNING=false
                REJOIN_COUNT=0
                start_rejoin_loop
                IS_RUNNING=false
                ;;
            3)
                menu_test
                ;;
            4)
                menu_log
                ;;
            5)
                show_guide
                ;;
            0)
                echo -e "${YELLOW}  Tam biet!${RESET}"
                exit 0
                ;;
            *)
                echo -e "${RED}  Lua chon khong hop le!${RESET}"
                sleep 1
                ;;
        esac
    done
}

trap '
    echo ""
    echo -e "${YELLOW}[!] Dung loop. Nhan Enter de quay lai menu...${RESET}"
    IS_RUNNING=false
    read -r
    main
' INT

main
