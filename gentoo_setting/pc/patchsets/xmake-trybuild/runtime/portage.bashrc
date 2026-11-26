# Managed by configure-portage-xmake.py
# Keep the real tools visible while Portage and CMake discover dependencies.
if [[ ${XMAKE_PORTAGE_BRIDGE-} == yes && -n ${T-} &&
      -x /usr/bin/xmake && -x /usr/local/libexec/portage-xmake/ninja ]]; then
    case ${EBUILD_PHASE-} in
        compile|test|install)
            case :${PATH}: in
                *:/usr/local/libexec/portage-xmake:*) ;;
                *) export PATH="/usr/local/libexec/portage-xmake:${PATH}" ;;
            esac
            einfo "xmake bridge: Ninja resolves to $(type -P ninja)"
            ;;
    esac
fi
