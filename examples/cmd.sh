#!/system/bin/sh
# A command is a file. The file name is the command's name, and the verbs are
# functions named svc_<verb>. This skeleton prints key=value; a real check exits
# non-zero and prints "diff key: why" when the platform is not in line with intent.
#
# Install: cp cmd.sh TREE/bin/<name>; chmod 755 TREE/bin/<name>
set -u

kv() { printf '%s=%s\n' "$1" "$2"; }
say() { printf '%s\n' "$*"; }

VERBS="status check apply"

svc_status() {
    kv mode "$( [ "$(id -u 2>/dev/null)" = 0 ] && echo root || echo shell )"
    kv functions "$(svc usb getFunctions 2>&1 | head -n 1)"
    kv boot "$(getprop sys.boot_completed 2>/dev/null)"
}

svc_check() {
    rc=0
    case "$(svc usb getFunctions 2>&1)" in
        *rndis*) : ;;
        *) echo "diff usb_functions: no rndis"; rc=1 ;;
    esac
    return "$rc"
}

svc_apply() {
    # Change only when needed: a reset of a correct gadget drops the link.
    case "$(svc usb getFunctions 2>&1)" in
        *rndis*) say "rndis already active" ;;
        *) svc usb setFunctions rndis; say "applied rndis" ;;
    esac
}

verb=${1:-status}
case " $VERBS " in
    *" $verb "*) "svc_$verb" ;;
    *) echo "usage: ${0##*/} [$VERBS]" >&2; exit 64 ;;
esac
