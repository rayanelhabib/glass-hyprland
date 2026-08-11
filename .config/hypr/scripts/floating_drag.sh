#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ FLOATING DRAG DAEMON — "drop and stay"
#
#  When a TILED window is dragged with the mouse, Hyprland floats it while
#  dragging but hard-codes re-tiling it on mouse release (DragController).
#  So the window snaps back to its original tile slot and "doesn't hold"
#  where you dropped it.
#
#  This daemon watches socket2 and undoes that: if a window that was just
#  being moved gets re-tiled, it re-floats it at the exact drop position.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
TMP="/tmp/floating_drag"
LOG="$TMP.log"
mkdir -p "$TMP"

# Single instance: record main PID so the daemon can be stopped cleanly.
PIDFILE="$TMP/daemon.pid"
if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    sleep 0.1
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"; exit 0' EXIT INT TERM

log() { echo "$(date +%H:%M:%S.%3N) $*" >> "$LOG"; }

win_state() { # addr -> "floating|tiled|gone [x y]"
    hyprctl -j clients 2>/dev/null | jq -rc --arg a "$1" '
        [ .[] | select(.address == ("0x" + $a)) | [ .floating, (.at[0]|tostring), (.at[1]|tostring) ] | join(" ") ][0] // "gone"'
}

poll_position() { # addr — record position of a floating window while it moves
    local addr="$1"
    local posfile="$TMP/$addr.pos" movefile="$TMP/$addr.move"
    local last_seen now st fl x y prev
    last_seen=$(date +%s%3N)
    while :; do
        [[ ! -f "$PIDFILE" ]] && break
        st=$(win_state "$addr")
        [[ "$st" == "gone" ]] && break
        fl=${st%% *}
        [[ "$fl" != "true" ]] && break
        x=$(awk '{print $2}' <<<"$st")
        y=$(awk '{print $3}' <<<"$st")
        now=$(date +%s%3N)
        prev=$(cat "$posfile" 2>/dev/null)
        if [[ -n "$prev" && "$prev" != "$x $y" ]]; then
            echo "$x $y" > "$posfile"
            echo "$now" > "$movefile"
            last_seen=$now
        elif [[ -z "$prev" ]]; then
            echo "$x $y" > "$posfile"
            last_seen=$now
        fi
        if (( now - last_seen > 4000 )); then
            log "poll idle-exit $addr"
            break
        fi
        sleep 0.03
    done
}

restore() { # addr fsd — re-float the window at its recorded drop position
    local addr="$1" fsd="$2"
    local posfile="$TMP/$addr.pos"
    local pos
    pos=$(cat "$posfile" 2>/dev/null)
    [[ -z "$pos" ]] && return
    log "restore $addr at $pos fsd=$fsd"
    touch "$TMP/$addr.restore"
    # wait for the re-tile to actually happen before re-floating
    local tries=0 st fl
    fl=""
    while (( tries < 100 )); do
        st=$(win_state "$addr")
        [[ "$st" == "gone" ]] && { rm -f "$TMP/$addr.restore"; return; }
        fl=${st%% *}
        [[ "$fl" == "false" ]] && break
        tries=$((tries + 1)); sleep 0.02
    done
    if [[ "$fl" != "false" ]]; then
        rm -f "$TMP/$addr.restore"
        return
    fi
    hyprctl dispatch "hl.dsp.window.float({ action = \"enable\", window = \"address:0x$addr\" })" >/dev/null 2>&1
    sleep 0.03
    hyprctl dispatch "hl.dsp.window.move({ x = ${pos% *}, y = ${pos#* }, window = \"address:0x$addr\" })" >/dev/null 2>&1
    if [[ "$fsd" == "1" ]]; then
        local mode
        mode=$(cat "$TMP/$addr.fsmode" 2>/dev/null || echo 1)
        hyprctl dispatch "hl.dsp.window.fullscreen_state({ internal = $mode, client = 0, window = \"address:0x$addr\" })" >/dev/null 2>&1
    fi
    rm -f "$TMP/$addr.restore"
}

cleanup() { # addr
    local addr="$1"
    local pid
    pid=$(cat "$TMP/$addr.pid" 2>/dev/null)
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
    rm -f "$TMP/$addr.pid" "$TMP/$addr.pos" "$TMP/$addr.move" "$TMP/$addr.fs" "$TMP/$addr.fsdrag" "$TMP/$addr.fsmode"
}

log "daemon start"
socat -U - "UNIX-CONNECT:$SOCKET" 2>/dev/null | while IFS= read -r ev; do
    case "$ev" in
        changefloatingmode\>\>*)
            body=${ev#*>>}
            addr=${body%%,*}
            mode=${body##*,}
            if [[ "$mode" == "1" ]]; then
                if [[ -f "$TMP/$addr.restore" ]]; then
                    rm -f "$TMP/$addr.restore"
                    continue
                fi
                # was this float the start of a drag of a fullscreen window?
                fsd=0
                if [[ -n "${fs_off_time:-0}" && -n "${fs_off_addr:-}" && "$fs_off_addr" == "$addr" ]]; then
                    local_now=$(date +%s%3N)
                    if (( local_now - fs_off_time <= 1500 )); then
                        fsd=1
                    fi
                fi
                fs_off_time=0
                fs_off_addr=
                echo "$fsd" > "$TMP/$addr.fs"
                rm -f "$TMP/$addr.pos" "$TMP/$addr.move"
                poll_position "$addr" &
                echo $! > "$TMP/$addr.pid"
            else
                pid=$(cat "$TMP/$addr.pid" 2>/dev/null)
                [[ -n "$pid" ]] && kill "$pid" 2>/dev/null
                rm -f "$TMP/$addr.pid"
                now=$(date +%s%3N)
                lastmove=$(cat "$TMP/$addr.move" 2>/dev/null)
                fsd=$(cat "$TMP/$addr.fs" 2>/dev/null || echo 0)
                rm -f "$TMP/$addr.fs"
                log "evt tile $addr now=$now lastmove=$lastmove diff=$(( now - lastmove )) fsd=$fsd"
                if [[ -n "$lastmove" && $(( now - lastmove )) -le 2500 ]]; then
                    restore "$addr" "$fsd"
                fi
                rm -f "$TMP/$addr.pos" "$TMP/$addr.move"
            fi
            ;;
        fullscreen\>\>*)
            mode=${ev#*>>}
            if [[ "$mode" == "1" ]]; then
                # record the exact mode of the (focused) window that entered fullscreen
                fsa=$(hyprctl -j activewindow 2>/dev/null | jq -r '.address' | sed 's/^0x//')
                fsm=$(hyprctl -j activewindow 2>/dev/null | jq -r '.fullscreen')
                [[ -n "$fsa" && "$fsm" != "0" ]] && echo "$fsm" > "$TMP/$fsa.fsmode"
            else
                # fullscreen off — if the same window floats shortly after, it's a drag
                fs_off_time=$(date +%s%3N)
                fs_off_addr=$(hyprctl -j activewindow 2>/dev/null | jq -r '.address' | sed 's/^0x//')
            fi
            ;;
        closewindow\>\>*)
            cleanup "${ev#*>>}"
            ;;
    esac
done
